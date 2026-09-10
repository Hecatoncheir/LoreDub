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

  if (skippedStoreAlias) throw const LoreDubFailure(FailureCode.pythonStoreAlias);
  throw LoreDubFailure(FailureCode.pythonMissing, detail: candidate);
}
