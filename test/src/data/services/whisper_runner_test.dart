// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/whisper_runner.dart';
import 'package:lore_dub/src/domain/failure.dart';

import '../../../support/fake_worker.dart';

void main() {
  late FakeWorker whisper;
  late WhisperRunner runner;
  late List<List<String>> started;

  setUp(() {
    whisper = FakeWorker();
    started = [];
    runner = WhisperRunner(
      start: (executable, arguments) async {
        started.add([executable, ...arguments]);
        return whisper;
      },
      limit: const Duration(milliseconds: 50),
    );
  });

  test('answers with how the run ended and what it printed', () async {
    final running = runner.run('whisper-cli.exe', ['-f', 'phrase.wav']);
    await settle();
    whisper.complain('auto-detected language: ja');
    await settle();
    whisper.exit(0);

    final run = await running;
    expect(started.single, ['whisper-cli.exe', '-f', 'phrase.wav']);
    expect(run.exitCode, 0);
    expect(run.stderr, contains('auto-detected language: ja'));
  });

  test('ends a run that never answers, rather than holding every phrase behind it', () async {
    final running = runner.run('whisper-cli.exe', const []);

    await expectLater(
      running,
      throwsA(isA<LoreDubFailure>().having((f) => f.code, 'code', FailureCode.whisperFailed)),
    );
    expect(whisper.killed, isTrue);
  });

  test('a stop ends the run under way', () async {
    final running = runner.run('whisper-cli.exe', const []);
    await settle();

    runner.cancel();

    expect(whisper.killed, isTrue);
    expect((await running).exitCode, isNot(0));
  });
}
