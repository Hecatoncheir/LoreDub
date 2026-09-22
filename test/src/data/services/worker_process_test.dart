// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/worker_process.dart';
import 'package:lore_dub/src/domain/failure.dart';

import '../../../support/fake_worker.dart';

void main() {
  late FakeWorker process;
  late List<(LoreDubFailure, bool)> died;
  late List<String> progress;
  late WorkerProcess worker;

  setUp(() {
    process = FakeWorker();
    died = [];
    progress = [];
    worker = WorkerProcess(
      process,
      onProgress: (value, stage) => progress.add(stage),
      onDied: (_, error, {required starting}) => died.add((error, starting)),
    );
  });

  Matcher failsWith(FailureCode code) =>
      throwsA(isA<LoreDubFailure>().having((failure) => failure.code, 'code', code));

  test('answers the handshake with where the worker put each stage', () async {
    final handshake = worker.handshake(const Duration(seconds: 5));
    process
      ..say({'type': 'progress', 'value': 0.4, 'stage': 'translation'})
      ..say({'type': 'ready', 'device': 'cuda', 'speechDevice': 'cpu'});

    final said = await handshake;
    expect(said['device'], 'cuda');
    expect(progress, ['translation']);
  });

  test('a worker that dies while it starts fails the start with what it said', () async {
    final handshake = worker.handshake(const Duration(seconds: 5));
    process.complain('ModuleNotFoundError: torch');
    await settle();
    process.exit(1);

    await expectLater(handshake, failsWith(FailureCode.workerExited));
    expect(died.single.$2, isTrue, reason: 'the start is told, not the session');
  });

  test('one that dies once up tells whoever holds the session', () async {
    final handshake = worker.handshake(const Duration(seconds: 5));
    process.say({'type': 'ready'});
    await handshake;

    process.exit(-1);
    await settle();

    expect(died.single.$1.code, FailureCode.workerExitedSilently);
    expect(died.single.$2, isFalse);
  });

  test('ending it fails what waits on it, and it answers for nobody after', () async {
    final handshake = worker.handshake(const Duration(seconds: 5));
    process.say({'type': 'ready'});
    await handshake;
    final asked = worker.request({'text': 'Hi'}, timeout: const Duration(seconds: 5));

    final failed = expectLater(asked, failsWith(FailureCode.pipelineStopped));
    await worker.end();

    await failed;
    expect(process.killed, isTrue);
    expect(died, isEmpty, reason: 'an exit asked for is no death');
  });

  test('gives up on a worker that never says it is ready, and ends it', () async {
    await expectLater(
      worker.handshake(const Duration(milliseconds: 20)),
      failsWith(FailureCode.workerStartTimeout),
    );
    expect(process.killed, isTrue);
  });
}
