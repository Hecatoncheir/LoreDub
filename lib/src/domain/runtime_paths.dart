// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:path/path.dart' as path;

import 'compute_device.dart';
import 'failure.dart';

/// Threads to hand to whisper.cpp and torch by default.
///
/// Recognition dominates the delay before a phrase is voiced and scales well
/// with threads, so a fixed small number wastes a modern CPU. Half of the
/// logical processors keeps the game responsive while roughly halving the
/// wait compared to four threads.
int defaultCpuThreads([int? logicalProcessors]) {
  final available = logicalProcessors ?? Platform.numberOfProcessors;
  if (available <= 4) return 2;
  return (available ~/ 2).clamp(4, 12);
}

String bundledRuntimeDirectory() =>
    path.join(File(Platform.resolvedExecutable).parent.path, 'runtime');

String bundledPythonExecutablePath({String? runtimeDirectory}) =>
    path.join(runtimeDirectory ?? bundledRuntimeDirectory(), 'python', 'python.exe');

/// Each whisper.cpp build gets its own folder: they ship ggml libraries of
/// the same name compiled against different backends, so mixing them in one
/// directory would load whichever happened to be copied last.
String whisperBackendDirectory(ComputeBackend backend) => switch (backend) {
  ComputeBackend.cpu => 'whisper',
  ComputeBackend.vulkan => 'whisper-vulkan',
  ComputeBackend.cuda => 'whisper-cuda',
};

String whisperExecutablePath({
  String? runtimeDirectory,
  ComputeBackend backend = ComputeBackend.cpu,
}) => path.join(
  runtimeDirectory ?? bundledRuntimeDirectory(),
  whisperBackendDirectory(backend),
  'whisper-cli.exe',
);

/// Verifies the whisper.cpp binary before the pipeline ducks the game and
/// starts capturing, so a missing runtime is reported instead of silently
/// swallowing every captured phrase.
///
/// The CPU and Vulkan builds ship with the application; the CUDA one is
/// downloaded, so it is looked for under [downloadedRuntimeDirectory].
Future<String> resolveWhisperExecutable({
  String? runtimeDirectory,
  String? downloadedRuntimeDirectory,
  ComputeBackend backend = ComputeBackend.cpu,
}) async {
  final root = backend == ComputeBackend.cuda
      ? downloadedRuntimeDirectory ?? runtimeDirectory
      : runtimeDirectory;
  final candidate = whisperExecutablePath(runtimeDirectory: root, backend: backend);
  if (await File(candidate).exists()) return candidate;
  throw LoreDubFailure(FailureCode.whisperMissing, detail: candidate);
}

/// Windows ships `%LOCALAPPDATA%\Microsoft\WindowsApps\python.exe` as an app
/// execution alias. It only advertises the Microsoft Store and exits, so it can
/// never run the worker. A real Store installation lives in a package
/// subdirectory instead of directly inside `WindowsApps`.
bool isWindowsStoreAliasStub(String executablePath) =>
    path.basename(path.dirname(executablePath)).toLowerCase() == 'windowsapps';

/// The interpreter the worker is to be started with.
///
/// A setting that names a file is taken as it is; a bare name is looked for
/// along PATH. The Store alias stub is passed over wherever it turns up, and
/// if it is the only thing found it is its own failure: telling the player to
/// install Python is no answer when Windows has put a decoy in front of them.
Future<String> resolvePythonExecutable(String configured) async {
  final candidate = configured.trim().isEmpty ? bundledPythonExecutablePath() : configured.trim();
  var skippedStoreAlias = false;

  final named = File(candidate);
  if (await named.exists()) {
    if (!isWindowsStoreAliasStub(named.path)) return named.absolute.path;
    skippedStoreAlias = true;
  }

  if (_isBareName(candidate)) {
    final found = await _alongPath(candidate);
    if (found.executable case final executable?) return executable;
    skippedStoreAlias = skippedStoreAlias || found.skippedStoreAlias;
  }

  if (skippedStoreAlias) throw const LoreDubFailure(FailureCode.pythonStoreAlias);
  throw LoreDubFailure(FailureCode.pythonMissing, detail: candidate);
}

/// What a search turned up: the interpreter to run, or — having found none —
/// whether the Store decoy was among what it passed over.
class _PythonSearch {
  const _PythonSearch({this.executable, this.skippedStoreAlias = false});

  final String? executable;
  final bool skippedStoreAlias;
}

/// Looks for [name] in every directory of PATH, in order.
Future<_PythonSearch> _alongPath(String name) async {
  var skippedStoreAlias = false;
  for (final directory in _pathDirectories()) {
    for (final fileName in _fileNamesFor(name)) {
      final candidate = File(path.join(directory, fileName));
      if (!await candidate.exists()) continue;
      if (isWindowsStoreAliasStub(candidate.path)) {
        skippedStoreAlias = true;
        continue;
      }
      return _PythonSearch(executable: candidate.absolute.path);
    }
  }
  return _PythonSearch(skippedStoreAlias: skippedStoreAlias);
}

/// A name with no directory in it is looked for along PATH; anything else is
/// a place the player named, and there is nowhere else to look.
bool _isBareName(String candidate) => !candidate.contains('/') && !candidate.contains(r'\');

Iterable<String> _pathDirectories() => (Platform.environment['PATH'] ?? '')
    .split(Platform.isWindows ? ';' : ':')
    .where((directory) => directory.trim().isNotEmpty);

/// The file names one bare name can stand for: on Windows it is spelled with
/// the extension as well, the way the shell would complete it.
Set<String> _fileNamesFor(String name) => {
  name,
  if (Platform.isWindows && !name.toLowerCase().endsWith('.exe')) '$name.exe',
};
