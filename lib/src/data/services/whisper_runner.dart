// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:io';

import '../../domain/failure.dart';
import 'process_launcher.dart';

/// What one run of whisper printed, and how it ended.
typedef WhisperRun = ({int exitCode, String stdout, String stderr});

/// whisper.cpp, run once per phrase as a program of its own.
///
/// Watched rather than left to run: a recognition that hangs -- a driver
/// that never answers, a model file half-written -- would hold every phrase
/// behind it, since phrases are recognized one at a time, and a stop could
/// not end it. So a run is given [limit] and [cancel] ends the one under way.
class WhisperRunner {
  WhisperRunner({ProcessLauncher? start, this.limit = const Duration(minutes: 2)})
    : _start = start ?? Process.start;

  final ProcessLauncher _start;

  /// The longest one phrase may take. Recognition is seconds; this is only
  /// what tells a run that will never end from a slow one.
  final Duration limit;

  /// The run under way, which [cancel] ends.
  Process? _running;

  /// Runs [executable] with [arguments] to its end and answers with what it
  /// printed. Fails as `whisperFailed` when it runs past [limit].
  Future<WhisperRun> run(String executable, List<String> arguments) async {
    final process = await _start(executable, arguments);
    _running = process;
    try {
      final printed = process.stdout.transform(systemEncoding.decoder).join();
      final complained = process.stderr.transform(systemEncoding.decoder).join();
      final exitCode = await process.exitCode.timeout(
        limit,
        onTimeout: () {
          process.kill();
          throw LoreDubFailure(
            FailureCode.whisperFailed,
            detail: 'no answer within ${limit.inSeconds} s',
          );
        },
      );
      return (exitCode: exitCode, stdout: await printed, stderr: await complained);
    } finally {
      if (identical(_running, process)) _running = null;
    }
  }

  /// Ends the run under way, if there is one. What it was recognizing is
  /// wanted by nobody any more.
  void cancel() => _running?.kill();
}
