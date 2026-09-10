// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../../domain/runtime_paths.dart';

/// What a candidate interpreter turned out to be. [version] is empty when the
/// executable could not be started at all.
class PythonProbeResult {
  const PythonProbeResult({required this.version, required this.hasDependencies});

  const PythonProbeResult.unusable() : version = '', hasDependencies = false;

  final String version;
  final bool hasDependencies;

  bool get runs => version.isNotEmpty;
}

typedef PythonProbe = Future<PythonProbeResult> Function(String executable);

class PythonDiscoveryResult {
  const PythonDiscoveryResult({required this.executable, required this.rejected});

  /// The first interpreter that can run the worker, or null when none can.
  final String? executable;

  /// Everything that was found but turned down, with the reason.
  final List<String> rejected;

  String describeFailure() {
    if (rejected.isEmpty) {
      return 'Python не найден в PATH и в стандартных каталогах установки. '
          'Укажите путь к python.exe вручную или используйте встроенный runtime.';
    }
    return 'Не найден Python с torch и transformers. Проверено: ${rejected.join('; ')}.';
  }
}

/// Looks for an interpreter that can actually run the Marian/Silero worker.
///
/// Being first in PATH is not enough: the Microsoft Store alias resolves there
/// but only advertises the Store, and a plain installation without torch and
/// transformers dies on the first import.
class PythonDiscovery {
  PythonDiscovery({
    Map<String, String>? environment,
    PythonProbe? probe,
    String? bundledExecutable,
  }) : _environment = environment ?? Platform.environment,
       _probe = probe ?? _runProbe,
       _bundledExecutable = bundledExecutable ?? bundledPythonExecutablePath();

  static const _probeScript =
      'import sys, importlib.util as u; '
      'print(sys.version.split()[0]); '
      "print(bool(u.find_spec('torch') and u.find_spec('transformers')))";

  final Map<String, String> _environment;
  final PythonProbe _probe;
  final String _bundledExecutable;

  Future<PythonDiscoveryResult> find() async {
    final rejected = <String>[];
    for (final candidate in await _candidates()) {
      final result = await _probe(candidate);
      if (result.hasDependencies) {
        return PythonDiscoveryResult(executable: candidate, rejected: rejected);
      }
      rejected.add(
        result.runs
            ? '$candidate (Python ${result.version}, нет torch/transformers)'
            : '$candidate (не запускается)',
      );
    }
    return PythonDiscoveryResult(executable: null, rejected: rejected);
  }

  /// Ordered by how likely the interpreter is to be the right one: the runtime
  /// shipped with LoreDub first, then PATH, then the usual install locations.
  Future<List<String>> _candidates() async {
    final found = <String>[];
    final seen = <String>{};

    Future<void> consider(String candidate) async {
      if (candidate.trim().isEmpty) return;
      if (isWindowsStoreAliasStub(candidate)) return;
      final file = File(candidate);
      if (!await file.exists()) return;
      final normalized = path.normalize(file.absolute.path).toLowerCase();
      if (!seen.add(normalized)) return;
      found.add(file.absolute.path);
    }

    await consider(_bundledExecutable);
    // A previously installed LoreDub carries a runtime that is known to be
    // provisioned correctly, which beats an arbitrary interpreter from PATH.
    for (final runtime in _installedRuntimes()) {
      await consider(runtime);
    }

    final searchPath = _environment['PATH'] ?? _environment['Path'] ?? '';
    for (final directory in searchPath.split(Platform.isWindows ? ';' : ':')) {
      if (directory.trim().isEmpty) continue;
      for (final name in const ['python.exe', 'python3.exe', 'python', 'python3']) {
        await consider(path.join(directory.trim(), name));
      }
    }

    final home = _environment['PYTHONHOME'];
    if (home != null) await consider(path.join(home, 'python.exe'));

    for (final root in _installationRoots()) {
      for (final directory in await _pythonDirectories(root)) {
        await consider(path.join(directory, 'python.exe'));
      }
    }

    return found;
  }

  Iterable<String> _installedRuntimes() sync* {
    final localAppData = _environment['LOCALAPPDATA'];
    if (localAppData != null) {
      yield path.join(localAppData, 'Programs', 'LoreDub', 'runtime', 'python', 'python.exe');
    }
    final programFiles = _environment['ProgramFiles'];
    if (programFiles != null) {
      yield path.join(programFiles, 'LoreDub', 'runtime', 'python', 'python.exe');
    }
  }

  Iterable<String> _installationRoots() sync* {
    final localAppData = _environment['LOCALAPPDATA'];
    if (localAppData != null) yield path.join(localAppData, 'Programs', 'Python');
    final programFiles = _environment['ProgramFiles'];
    if (programFiles != null) yield programFiles;
    final programFilesX86 = _environment['ProgramFiles(x86)'];
    if (programFilesX86 != null) yield programFilesX86;
    final systemDrive = _environment['SystemDrive'];
    if (systemDrive != null) yield '$systemDrive${path.separator}';
  }

  static Future<List<String>> _pythonDirectories(String root) async {
    final directory = Directory(root);
    if (!await directory.exists()) return const [];
    try {
      final entries = await directory.list(followLinks: false).toList();
      return entries
          .whereType<Directory>()
          .map((entry) => entry.path)
          .where((entry) => path.basename(entry).toLowerCase().startsWith('python'))
          .toList();
    } on FileSystemException {
      return const [];
    }
  }

  static Future<PythonProbeResult> _runProbe(String executable) async {
    try {
      final result = await Process.run(executable, [
        '-c',
        _probeScript,
      ]).timeout(const Duration(seconds: 20));
      if (result.exitCode != 0) return const PythonProbeResult.unusable();
      final lines = const LineSplitter()
          .convert('${result.stdout}')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      if (lines.length < 2) return const PythonProbeResult.unusable();
      return PythonProbeResult(
        version: lines.first,
        hasDependencies: lines.last.toLowerCase() == 'true',
      );
    } on Object {
      return const PythonProbeResult.unusable();
    }
  }
}
