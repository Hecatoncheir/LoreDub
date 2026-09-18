// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/local_inference_service.dart';
import 'package:lore_dub/src/domain/compute_device.dart';
import 'package:lore_dub/src/domain/failure.dart';
import 'package:path/path.dart' as path;

import '../../../support/fake_worker.dart';
import '../../../support/temporary_directory.dart';

void main() {
  test('clears audio a stopped or crashed run left behind', () async {
    final work = await Directory.systemTemp.createTemp('lore-dub-work');
    addTearDown(() => deleteOnceReleased(work));
    final capture = Directory(path.join(work.path, 'capture'));
    await capture.create(recursive: true);
    Future<File> write(Directory directory, String name) =>
        File(path.join(directory.path, name)).writeAsString('audio');
    await write(work, 'speech-48.wav');
    await write(capture, 'segment-9000-3.wav');
    await write(work, 'inference_worker.py');
    await write(work, 'notes.wav.txt');

    await LocalInferenceService.removeStaleAudio(work);

    expect(File(path.join(work.path, 'speech-48.wav')).existsSync(), isFalse);
    expect(File(path.join(capture.path, 'segment-9000-3.wav')).existsSync(), isFalse);
    expect(File(path.join(work.path, 'inference_worker.py')).existsSync(), isTrue);
    expect(File(path.join(work.path, 'notes.wav.txt')).existsSync(), isTrue);
  });

  test('survives a work directory that does not exist yet', () async {
    final missing = Directory(path.join(Directory.systemTemp.path, 'lore-dub-absent-work'));

    await expectLater(LocalInferenceService.removeStaleAudio(missing), completes);
  });

  test('reads a translated reply written as UTF-8', () async {
    final reply = jsonEncode({'id': 1, 'translated': 'Ворота запечатаны.'});
    final Stream<List<int>> source = Stream.value(utf8.encode('$reply\n'));

    final lines = await decodeWorkerLines(source).toList();

    expect(lines, [reply]);
    expect(jsonDecode(lines.single), containsPair('translated', 'Ворота запечатаны.'));
  });

  test('survives a reply the interpreter wrote in the ANSI code page', () async {
    // cp1251 bytes for 'Вход' inside an otherwise ASCII JSON line: the decoder
    // must not tear the stream down and lose every later reply.
    final source = Stream.value([
      ...utf8.encode('{"id": 1, "translated": "'),
      0xC2,
      0xF5,
      0xEE,
      0xE4,
      ...utf8.encode('"}\n{"id": 2}\n'),
    ]);

    final lines = await decodeWorkerLines(source).toList();

    expect(lines, hasLength(2));
    expect(lines.last, '{"id": 2}');
  });

  test('splits replies that arrive in one chunk', () async {
    final Stream<List<int>> source = Stream.value(
      utf8.encode('{"type": "ready"}\n{"id": 7}\n'),
    );

    expect(await decodeWorkerLines(source).toList(), ['{"type": "ready"}', '{"id": 7}']);
  });

  test('reuses the language whisper detected confidently', () {
    const output = 'whisper_full_with_state: auto-detected language: en (p = 0.995430)';

    expect(parseDetectedLanguage(output), 'en');
  });

  test('stays on auto-detection when the guess is shaky', () {
    const output = 'whisper_full_with_state: auto-detected language: cy (p = 0.180000)';

    expect(parseDetectedLanguage(output), isNull);
  });

  test('stays on auto-detection when whisper printed no guess', () {
    expect(parseDetectedLanguage('whisper_print_timings: total time = 1176.00 ms'), isNull);
  });

  test('explains a worker crash with the reason it printed', () {
    final diagnostics = WorkerDiagnostics()
      ..add('Python was not found; run without arguments to install from the Microsoft Store');

    final failure = diagnostics.describeExit(9009);

    expect(failure.code, FailureCode.workerExited);
    expect(failure.detail, startsWith('9009'));
    expect(failure.detail, contains('Microsoft Store'));
  });

  test('keeps only the last stderr lines and drops blank ones', () {
    final diagnostics = WorkerDiagnostics(limit: 2)
      ..add('first')
      ..add('   ')
      ..add('')
      ..add('second')
      ..add('third');

    final detail = diagnostics.describeExit(1).detail!;

    expect(detail, isNot(contains('first')));
    expect(detail, contains('second'));
    expect(detail, contains('third'));
  });

  test('reports a silent death by its own code', () {
    final diagnostics = WorkerDiagnostics();

    expect(diagnostics.isEmpty, isTrue);
    expect(diagnostics.describeExit(1).code, FailureCode.workerExitedSilently);
    expect(diagnostics.describeExit(1).detail, '1');
  });

  test('forgets the previous run when the pipeline restarts', () {
    final diagnostics = WorkerDiagnostics()
      ..add('stale failure')
      ..clear();

    expect(diagnostics.describeExit(1).code, FailureCode.workerExitedSilently);
  });

  group('starting and stopping the worker', () {
    /// A machine with everything in place, and the workers it hands out in
    /// the order they are asked for.
    LocalInferenceService serviceWith(
      List<FakeWorker> workers, {
      Duration startupLimit = const Duration(minutes: 5),
    }) {
      final waiting = [...workers];
      return LocalInferenceService(
        prepare: everythingInPlace,
        startWorker: (executable, arguments) async => waiting.removeAt(0),
        startupLimit: startupLimit,
      );
    }

    Future<void> startOn(LocalInferenceService service) => service.start(
      threads: 2,
      speed: 1,
      pythonExecutable: 'python.exe',
      requiresWhisper: false,
    );

    Matcher failsWith(FailureCode code) =>
        throwsA(isA<LoreDubFailure>().having((failure) => failure.code, 'code', code));

    test('comes up once the worker says it is ready', () async {
      final worker = FakeWorker();
      final service = serviceWith([worker]);

      final starting = startOn(service);
      await settle();
      worker.say({'type': 'ready', 'device': 'cuda', 'speechDevice': 'cpu'});
      await starting;

      expect(service.translationBackend, ComputeBackend.cuda);
      expect(service.speechBackend, ComputeBackend.cpu);
      await service.stop();
      expect(worker.killed, isTrue);
    });

    test('a stop during the handshake ends the start at once, as stopped', () async {
      final worker = FakeWorker();
      final service = serviceWith([worker]);

      final starting = expectLater(startOn(service), failsWith(FailureCode.pipelineStopped));
      await settle();
      await service.stop();

      // The limit is five minutes here: waited out, this would never return.
      await starting.timeout(const Duration(seconds: 5));
      expect(worker.killed, isTrue);
    });

    test('a stop while the interpreter is coming up ends the worker it never saw', () async {
      final spawning = Completer<Process>();
      final service = LocalInferenceService(
        prepare: everythingInPlace,
        startWorker: (executable, arguments) => spawning.future,
      );

      final starting = expectLater(startOn(service), failsWith(FailureCode.pipelineStopped));
      await settle();
      await service.stop();
      final worker = FakeWorker();
      spawning.complete(worker);
      await starting;

      expect(worker.killed, isTrue, reason: 'nobody else holds it, so nobody else would end it');
      await expectLater(service.processText('Hello'), failsWith(FailureCode.workerNotRunning));
    });

    test('a stop while the machine is being asked starts no interpreter at all', () async {
      final preparing = Completer<WorkerFiles>();
      var spawned = 0;
      final service = LocalInferenceService(
        prepare: ({
          required pythonExecutable,
          required requiresWhisper,
          required recognitionBackend,
          downloadedRuntimeDirectory,
        }) => preparing.future,
        startWorker: (executable, arguments) async {
          spawned++;
          return FakeWorker();
        },
      );

      final starting = expectLater(startOn(service), failsWith(FailureCode.pipelineStopped));
      await service.stop();
      preparing.complete(workerFiles);
      await starting;

      expect(spawned, 0);
    });

    test('a later start takes over from one still waiting for its worker', () async {
      final first = FakeWorker();
      final second = FakeWorker();
      final service = serviceWith([first, second]);

      final replaced = expectLater(startOn(service), failsWith(FailureCode.pipelineStopped));
      await settle();
      final starting = startOn(service);
      await replaced;
      await settle();
      second.say({'type': 'ready', 'device': 'cpu'});
      await starting;

      expect(first.killed, isTrue);
      expect(second.killed, isFalse);
      await service.stop();
    });

    test('a worker on its way out answers for nobody, and takes nothing with it', () async {
      final first = FakeWorker(lingers: true);
      final second = FakeWorker();
      final service = serviceWith([first, second]);
      final cancelled = expectLater(startOn(service), failsWith(FailureCode.pipelineStopped));
      await settle();

      // The stop is still waiting for the first worker to die when the next
      // start brings its own up, so for a while there are two of them.
      final stopping = service.stop();
      await cancelled;
      var ready = false;
      final starting = startOn(service).then((_) => ready = true);
      await settle();
      first.say({'type': 'ready', 'device': 'cuda'});
      await settle();
      expect(ready, isFalse, reason: 'the handshake of the worker being replaced is not ours');

      second.say({'type': 'ready', 'device': 'cpu'});
      await starting;
      expect(service.translationBackend, ComputeBackend.cpu);

      first.exit(-1);
      await stopping;
      // The stop has finished with the first worker; the second one is
      // still listened to, which is what answers this line.
      final line = service.processText('Hello');
      await settle();
      second.say({'id': second.lastRequestId, 'translated': 'Привет', 'wave': 'speech-1.wav'});

      expect((await line).translated, 'Привет');
      await service.stop();
    });

    test('a worker that never says it is ready fails the start by name', () async {
      final worker = FakeWorker();
      final service = serviceWith([worker], startupLimit: const Duration(milliseconds: 50));

      final starting = startOn(service);
      final outcome = expectLater(
        starting,
        throwsA(
          isA<LoreDubFailure>()
              .having((failure) => failure.code, 'code', FailureCode.workerStartTimeout)
              .having((failure) => failure.detail, 'detail', contains('loading torch')),
        ),
      );
      await settle();
      worker.complain('loading torch');
      await outcome;

      expect(worker.killed, isTrue, reason: 'given up on, it is not left loading');
    });

    test('a worker that dies while starting fails the start with its reason', () async {
      final worker = FakeWorker();
      final lost = <LoreDubFailure>[];
      final service = serviceWith([worker])..onWorkerLost = lost.add;

      final starting = expectLater(startOn(service), failsWith(FailureCode.workerExited));
      await settle();
      worker.complain('ModuleNotFoundError: torch');
      await settle();
      worker.exit(1);
      await starting;

      expect(lost, isEmpty, reason: 'the start has already said so');
    });

    test('a worker that dies under a session is let go of, and says why', () async {
      final worker = FakeWorker();
      final lost = <LoreDubFailure>[];
      final service = serviceWith([worker])..onWorkerLost = lost.add;
      final starting = startOn(service);
      await settle();
      worker.say({'type': 'ready', 'device': 'cpu'});
      await starting;

      final line = expectLater(
        service.processText('Hello'),
        failsWith(FailureCode.workerExitedSilently),
      );
      await settle();
      worker.exit(3);
      await line;

      expect(lost.single.code, FailureCode.workerExitedSilently);
      expect(lost.single.detail, '3');
      // Told at once, rather than written into a pipe nobody reads and left
      // to wait out its two minutes.
      await expectLater(service.processText('Anyone?'), failsWith(FailureCode.workerNotRunning));
    });
  });
}
