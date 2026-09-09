// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:path/path.dart' as path;

String bundledPythonExecutablePath() => path.join(
  File(Platform.resolvedExecutable).parent.path,
  'runtime',
  'python',
  'python.exe',
);

Future<String> resolvePythonExecutable(String configured) async {
  final candidate = configured.trim().isEmpty ? bundledPythonExecutablePath() : configured.trim();
  final file = File(candidate);
  if (await file.exists()) return file.absolute.path;

  if (!candidate.contains('/') && !candidate.contains(r'\')) {
    final pathValue = Platform.environment['PATH'] ?? '';
    for (final directory in pathValue.split(Platform.isWindows ? ';' : ':')) {
      if (directory.trim().isEmpty) continue;
      for (final name in {
        candidate,
        if (Platform.isWindows && !candidate.toLowerCase().endsWith('.exe')) '$candidate.exe',
      }) {
        final pathCandidate = File(path.join(directory, name));
        if (await pathCandidate.exists()) return pathCandidate.absolute.path;
      }
    }
  }

  throw StateError('Не найден Python: $candidate');
}
