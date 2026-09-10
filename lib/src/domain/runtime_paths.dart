// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:path/path.dart' as path;

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

const runtimeSetupHint =
    'Установите LoreDub через setup или подготовьте runtime рядом с приложением '
    'командой scripts/prepare_windows_runtime.ps1.';

String bundledRuntimeDirectory() =>
    path.join(File(Platform.resolvedExecutable).parent.path, 'runtime');

String bundledPythonExecutablePath({String? runtimeDirectory}) =>
    path.join(runtimeDirectory ?? bundledRuntimeDirectory(), 'python', 'python.exe');

String whisperExecutablePath({String? runtimeDirectory}) =>
    path.join(runtimeDirectory ?? bundledRuntimeDirectory(), 'whisper', 'whisper-cli.exe');

/// Verifies the whisper.cpp binary before the pipeline ducks the game and
/// starts capturing, so a missing runtime is reported instead of silently
/// swallowing every captured phrase.
Future<String> resolveWhisperExecutable({String? runtimeDirectory}) async {
  final candidate = whisperExecutablePath(runtimeDirectory: runtimeDirectory);
  if (await File(candidate).exists()) return candidate;
  throw StateError('Не найден whisper-cli.exe: $candidate. $runtimeSetupHint');
}

/// Windows ships `%LOCALAPPDATA%\Microsoft\WindowsApps\python.exe` as an app
/// execution alias. It only advertises the Microsoft Store and exits, so it can
/// never run the worker. A real Store installation lives in a package
/// subdirectory instead of directly inside `WindowsApps`.
bool isWindowsStoreAliasStub(String executablePath) =>
    path.basename(path.dirname(executablePath)).toLowerCase() == 'windowsapps';

Future<String> resolvePythonExecutable(String configured) async {
  final candidate = configured.trim().isEmpty ? bundledPythonExecutablePath() : configured.trim();
  final file = File(candidate);
  var skippedStoreAlias = false;
  if (await file.exists()) {
    if (!isWindowsStoreAliasStub(file.path)) return file.absolute.path;
    skippedStoreAlias = true;
  }

  if (!candidate.contains('/') && !candidate.contains(r'\')) {
    final pathValue = Platform.environment['PATH'] ?? '';
    for (final directory in pathValue.split(Platform.isWindows ? ';' : ':')) {
      if (directory.trim().isEmpty) continue;
      for (final name in {
        candidate,
        if (Platform.isWindows && !candidate.toLowerCase().endsWith('.exe')) '$candidate.exe',
      }) {
        final pathCandidate = File(path.join(directory, name));
        if (!await pathCandidate.exists()) continue;
        if (isWindowsStoreAliasStub(pathCandidate.path)) {
          skippedStoreAlias = true;
          continue;
        }
        return pathCandidate.absolute.path;
      }
    }
  }

  if (skippedStoreAlias) {
    throw StateError(
      'В PATH найден только ярлык Microsoft Store вместо Python. Он не '
      'запускает интерпретатор. Выберите встроенный runtime или укажите полный '
      'путь к python.exe с установленными torch и transformers.',
    );
  }
  throw StateError('Не найден Python: $candidate. $runtimeSetupHint');
}
