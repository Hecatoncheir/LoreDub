// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/local_inference_service.dart';
import 'package:lore_dub/src/data/services/native_bridge.dart';
import 'package:lore_dub/src/data/services/native_engine_service.dart';
import 'package:lore_dub/src/domain/compute_device.dart';
import 'package:lore_dub/src/domain/engine_event.dart';
import 'package:lore_dub/src/domain/failure.dart';
import 'package:lore_dub/src/domain/hotkey.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart';
import 'package:lore_dub/src/domain/session_config.dart';
import 'package:lore_dub/src/data/services/worker_arguments.dart';
import 'package:path/path.dart' as path;

import '../../../support/fake_worker.dart';
import '../../../support/temporary_directory.dart';

void main() {
  test('turns a native capture error into a failure the banner can show', () {
    final event = fromNativeEvent({
      'type': 'error',
      'message': 'English OCR language is not installed.',
    });

    expect(
      event,
      isA<EngineFailed>().having(
        (event) => event.failure,
        'failure',
        isA<LoreDubFailure>()
            .having((failure) => failure.code, 'code', FailureCode.captureFailed)
            .having(
              (failure) => failure.detail,
              'detail',
              'English OCR language is not installed.',
            ),
      ),
    );
  });

  test('names the session a state belongs to, and leaves a resting one to all', () {
    const listening = {'type': 'state', 'state': 'listening'};

    expect(
      fromNativeEvent(listening, session: PipelineSession.scene),
      isA<SessionStateChanged>()
          .having((event) => event.status, 'status', PipelineStatus.listening)
          .having((event) => event.session, 'session', PipelineSession.scene),
    );
    expect(
      fromNativeEvent({'type': 'state', 'state': 'idle'}),
      isA<SessionStateChanged>()
          .having((event) => event.status, 'status', PipelineStatus.idle)
          .having((event) => event.concerns(PipelineSession.live), 'concerns anyone', isTrue),
    );
  });

  test('passes over a kind this build has nothing to do with', () {
    expect(fromNativeEvent({'type': 'somethingLater'}), isNull);
    // A key this build does not know is nothing to press.
    expect(fromNativeEvent({'type': 'hotkey', 'action': 'teleport'}), isNull);
  });

  test('names the action whose hotkey another program holds', () {
    final event = fromNativeEvent({'type': 'hotkeyTaken', 'action': 'resume'});

    expect(
      event,
      isA<EngineFailed>().having(
        (event) => event.failure,
        'failure',
        isA<LoreDubFailure>()
            .having((failure) => failure.code, 'code', FailureCode.hotkeyTaken)
            .having((failure) => failure.detail, 'detail', 'resume'),
      ),
    );
  });

  test('names the language Windows cannot read text in', () {
    final event = fromNativeEvent({'type': 'ocrLanguageMissing', 'language': 'ru'});

    expect(
      event,
      isA<EngineFailed>().having(
        (event) => event.failure,
        'failure',
        isA<LoreDubFailure>()
            .having((failure) => failure.code, 'code', FailureCode.ocrLanguageMissing)
            .having((failure) => failure.detail, 'detail', 'ru'),
      ),
    );
  });

  test('names the key that was pressed, for the pipeline to act on', () {
    expect(
      fromNativeEvent({'type': 'hotkey', 'action': 'pause'}),
      isA<HotkeyPressed>().having((event) => event.action, 'action', HotkeyAction.pause),
    );
  });

  test('retries when a native string grows between size and copy', () {
    const initialValue = '[]';
    const grownValue = '[{"pid":42,"name":"Игра.exe"}]';
    final initialBytes = utf8.encode(initialValue);
    final grownBytes = utf8.encode(grownValue);
    var calls = 0;

    int reader(Pointer<Char> output, int capacity) {
      calls++;
      if (output == nullptr) return initialBytes.length;
      if (capacity <= grownBytes.length) return grownBytes.length;
      output.cast<Uint8>().asTypedList(capacity)
        ..setRange(0, grownBytes.length, grownBytes)
        ..[grownBytes.length] = 0;
      return grownBytes.length;
    }

    final result = readNativeUtf8String(
      reader,
      throwIfError: (code) => fail('Unexpected native error: $code'),
    );

    expect(result, grownValue);
    expect(calls, 3);
  });

  test('a value that never settles is a failure, not a raw exception', () {
    // Eight tries at a string that grows every time. What comes out has to
    // be something the banner can word: a `FormatException` reached the
    // player as it came.
    var length = 8;

    int forever(Pointer<Char> output, int capacity) => length += 8;

    expect(
      () => readNativeUtf8String(forever, throwIfError: (code) => fail('no error: $code')),
      throwsA(
        isA<LoreDubFailure>().having(
          (failure) => failure.code,
          'code',
          FailureCode.nativeCallFailed,
        ),
      ),
    );
  });

  test('drops a line whose answer arrives once its session has ended', () async {
    final work = await Directory.systemTemp.createTemp('lore-dub-engine');
    addTearDown(() => deleteOnceReleased(work));
    final native = _FakeNative();
    final inference = _HeldInference();
    final engine = NativeEngineService(
      inference: inference,
      native: native,
      workDirectory: () async => work,
    );
    final events = <EngineEvent>[];
    engine.events.listen(events.add);

    await engine.startScreenText(
      const ScreenSessionConfig(
        worker: WorkerPlan(threads: 2, pythonExecutable: 'python.exe', runtimeDirectory: 'rt'),
        capture: CapturePlan(mode: CaptureMode.ocr, processId: 7),
        lines: LineRules(targetLanguage: 'ru'),
      ),
    );
    native.push('{"type":"ocrText","text":"The gate is sealed."}');
    await _until(() => inference.asked.isNotEmpty);

    // The worker was answering as the stop came.
    await engine.stop();
    final wave = File(path.join(work.path, 'line.wav'))..writeAsBytesSync([0]);
    inference.asked.single.complete(
      InferenceResult(
        english: 'The gate is sealed.',
        translated: 'Ворота закрыты.',
        wavePath: wave.path,
      ),
    );
    // Let go of in the background: waited for until it is gone, which the
    // test's own timeout ends if it never is.
    await _until(() => !wave.existsSync());

    expect(events.whereType<LineDubbed>(), isEmpty, reason: 'nobody is listening for it');
  });

  group('a start that is stopped or replaced', () {
    late Directory work;
    late _HeldWorkDirectory held;
    late _FakeNative native;
    late List<FakeWorker> workers;
    late NativeEngineService engine;
    late List<EngineEvent> events;
    var disposed = false;

    setUp(() async {
      work = await Directory.systemTemp.createTemp('lore-dub-engine');
      addTearDown(() => deleteOnceReleased(work));
      held = _HeldWorkDirectory(work);
      native = _FakeNative();
      workers = [];
      disposed = false;
      engine = NativeEngineService(
        inference: LocalInferenceService(
          prepare: everythingInPlace,
          startWorker: (executable, arguments) async {
            final worker = FakeWorker();
            workers.add(worker);
            return worker;
          },
        ),
        native: native,
        workDirectory: held.call,
      );
      events = [];
      engine.events.listen(events.add);
    });

    tearDown(() async {
      // Ends the poll timer of a session a test left running.
      if (!disposed) await engine.stop();
    });

    /// The session that waits on both sides of its worker: stale audio is
    /// cleared before it, and the capture directory made after it.
    const converterOnly = WorkerPlan(
      threads: 2,
      pythonExecutable: 'python.exe',
      runtimeDirectory: 'runtime',
      models: ModelPaths(converter: 'converter'),
    );
    SceneSessionConfig sceneOf(int processId) => SceneSessionConfig(
      worker: converterOnly,
      capture: CapturePlan(mode: CaptureMode.audio, processId: processId),
    );

    /// The session with no wait of its own: the worker, and nothing native.
    const preview = PreviewSessionConfig(
      worker: WorkerPlan(
        threads: 2,
        pythonExecutable: 'python.exe',
        runtimeDirectory: 'runtime',
        models: ModelPaths(speech: 'speech.pt'),
        speaker: 'xenia',
      ),
    );

    Matcher failsWith(FailureCode code) =>
        throwsA(isA<LoreDubFailure>().having((failure) => failure.code, 'code', code));

    /// Takes a start past its stale audio and its worker, and leaves it
    /// waiting for the capture directory — the [asked]th time the work
    /// directory is asked for.
    Future<FakeWorker> untilCaptureDirectory({
      int worker = 1,
      int asked = 2,
      Map<String, Object?> ready = const {'type': 'ready', 'device': 'cpu'},
    }) async {
      held.handOver();
      await _until(() => workers.length == worker);
      await settle();
      workers.last.say(ready);
      await _until(() => held.asked == asked);
      return workers.last;
    }

    List<T> eventsOf<T extends EngineEvent>() => events.whereType<T>().toList();

    test('starts the capture in the directory it made, once the worker is up', () async {
      final starting = engine.startScene(sceneOf(7));
      final worker = await untilCaptureDirectory();
      expect(native.started, isEmpty, reason: 'the directory it captures into is not there yet');
      held.handOver();
      await starting;

      final capture = path.join(work.path, 'capture');
      expect(native.started.single, containsPair('captureDirectory', capture));
      // Only the capture crosses into the library, flat, as its hand-written
      // parser wants: the worker's half stays on this side.
      expect(native.started.single, containsPair('processId', 7));
      expect(native.started.single.values.whereType<Map<Object?, Object?>>(), isEmpty);
      expect(native.started.single, isNot(contains('models')));
      expect(Directory(capture).existsSync(), isTrue);
      // What the capture reports is read, and named for the session it is.
      await _until(() => eventsOf<SessionStateChanged>().length == 2);
      expect(
        eventsOf<SessionStateChanged>().last,
        isA<SessionStateChanged>()
            .having((event) => event.status, 'status', PipelineStatus.listening)
            .having((event) => event.session, 'session', PipelineSession.scene),
      );

      await engine.stop();
      expect(worker.killed, isTrue);
      expect(native.stops, 1);
    });

    test('says where the worker put each stage before the capture starts', () async {
      final starting = engine.start(
        const LiveSessionConfig(
          worker: WorkerPlan(
            threads: 2,
            pythonExecutable: 'python.exe',
            runtimeDirectory: 'runtime',
            models: ModelPaths(whisper: 'ggml.bin', speech: 'speech.pt', converter: 'converter'),
            speaker: 'xenia',
            sourceLanguage: 'en',
          ),
          capture: CapturePlan(mode: CaptureMode.audio, processId: 7),
          lines: LineRules(targetLanguage: 'ru'),
        ),
      );
      await untilCaptureDirectory(
        ready: {
          'type': 'ready',
          'device': 'cuda',
          'speechDevice': 'cpu',
          'converterDevice': 'cuda',
        },
      );
      held.handOver();
      await starting;

      expect(
        [
          for (final event in events)
            if (event case BackendSettled(:final stage, :final backend))
              (stage, backend)
            else if (event case StartupProgressed(stage: 'capture', :final value))
              value,
        ],
        [
          (ComputeStage.translation, ComputeBackend.cuda),
          (ComputeStage.speech, ComputeBackend.cpu),
          (ComputeStage.voiceConversion, ComputeBackend.cuda),
          // Said once the last of them is: the capture is what is left.
          0.98,
        ],
      );
    });

    test('a stop while stale audio is cleared brings up no worker and no capture', () async {
      final starting = expectLater(
        engine.startScene(sceneOf(7)),
        failsWith(FailureCode.pipelineStopped),
      );
      // The stop finds no worker, and no start of the worker's to cancel, so
      // nothing but the engine's own count tells the start it is over.
      await engine.stop();
      held.handOver();
      await starting;
      await settle();

      expect(workers, isEmpty);
      expect(native.started, isEmpty);
      // The engine came to rest once, under nobody's name, and the start
      // said nothing after that for a screen to take as its own.
      expect(
        eventsOf<SessionStateChanged>(),
        [
          isA<SessionStateChanged>()
              .having((event) => event.status, 'status', PipelineStatus.idle)
              .having((event) => event.session, 'session', isNull),
        ],
      );
      expect(eventsOf<StartupProgressed>(), isEmpty);
    });

    test('a stop while the capture directory is made begins no capture', () async {
      final starting = expectLater(
        engine.startScene(sceneOf(7)),
        failsWith(FailureCode.pipelineStopped),
      );
      final worker = await untilCaptureDirectory();

      await engine.stop();
      expect(worker.killed, isTrue);
      held.handOver();
      await starting;

      expect(native.started, isEmpty, reason: 'a capture with no worker fails every phrase');
    });

    test('a worker that dies while the capture directory is made ends the start', () async {
      final starting = expectLater(
        engine.startScene(sceneOf(7)),
        failsWith(FailureCode.pipelineStopped),
      );
      final worker = await untilCaptureDirectory();

      worker.complain('CUDA out of memory');
      await settle();
      worker.exit(1);
      await _until(() => native.stops == 1);
      held.handOver();
      await starting;

      expect(native.started, isEmpty);
      // The start ends as stopped, which the screens pass over; what the
      // player is told is what the worker said.
      expect(
        eventsOf<EngineFailed>().single.failure,
        isA<LoreDubFailure>()
            .having((failure) => failure.code, 'code', FailureCode.workerExited)
            .having((failure) => failure.detail, 'detail', contains('CUDA out of memory')),
      );
    });

    test('a later start takes the engine over from one whose worker had just come up', () async {
      final replaced = expectLater(
        engine.startScene(sceneOf(7)),
        failsWith(FailureCode.pipelineStopped),
      );
      final first = await untilCaptureDirectory();

      // Asks for its worker at once, which ends the first one's.
      final starting = engine.startPreview(preview);
      held.handOver();
      await replaced;
      await _until(() => workers.length == 2);
      await settle();
      workers.last.say({'type': 'ready', 'speechDevice': 'cpu'});
      await starting;
      await settle();

      expect(first.killed, isTrue);
      expect(workers.last.killed, isFalse, reason: 'not the replaced start to end');
      expect(
        native.started,
        isEmpty,
        reason: 'the scene was replaced, and a sample captures nothing',
      );
      expect(
        eventsOf<SessionStateChanged>().last,
        isA<SessionStateChanged>()
            .having((event) => event.status, 'status', PipelineStatus.listening)
            .having((event) => event.session, 'session', PipelineSession.preview),
      );
    });

    test('a replaced start ends its worker while nobody else has asked for one', () async {
      final replaced = expectLater(
        engine.startScene(sceneOf(7)),
        failsWith(FailureCode.pipelineStopped),
      );
      final first = await untilCaptureDirectory();

      // Still clearing stale audio: it has not reached the worker, so the
      // first start's is left running with nobody holding it.
      final starting = engine.startCharacters(
        const CharactersSessionConfig(
          worker: converterOnly,
          capture: CapturePlan(mode: CaptureMode.audio, processId: 9),
        ),
      );
      expect(held.asked, 3);
      held.handOver();
      await replaced;
      expect(first.killed, isTrue);

      final second = await untilCaptureDirectory(worker: 2, asked: 4);
      held.handOver();
      await starting;

      expect(second.killed, isFalse);
      expect(native.started.single, containsPair('processId', 9));
    });

    test('a capture that will not start ends the worker brought up for it', () async {
      native.startCode = -6;
      final starting = expectLater(
        engine.startScene(sceneOf(7)),
        throwsA(
          isA<LoreDubFailure>()
              .having((error) => error.code, 'code', FailureCode.nativeCallFailed)
              // The code and what the library said about it, for the
              // banner to word rather than print.
              .having((error) => error.detail, 'detail', '-6: native error -6'),
        ),
      );
      final worker = await untilCaptureDirectory();
      held.handOver();
      await starting;

      expect(worker.killed, isTrue);
    });

    test('a stop the library refuses still ends the worker on this side', () async {
      final starting = engine.startScene(sceneOf(7));
      final worker = await untilCaptureDirectory();
      held.handOver();
      await starting;

      native.stopCode = -4;
      await expectLater(engine.stop(), failsWith(FailureCode.nativeCallFailed));

      // Left running, the worker held its models for nobody and the poll
      // went on reading a capture that was meant to be over.
      expect(worker.killed, isTrue);
      native.stopCode = 0;
    });

    test('a start still on its way when the engine is disposed of goes no further', () async {
      final starting = expectLater(
        engine.startScene(sceneOf(7)),
        failsWith(FailureCode.pipelineStopped),
      );
      final worker = await untilCaptureDirectory();

      engine.dispose();
      disposed = true;
      held.handOver();
      await starting;

      expect(native.started, isEmpty);
      // Disposing does not wait for the worker to go, so neither can this.
      await _until(() => worker.killed);
    });
  });
}

/// Waits for what a start only reaches through real file work, which no
/// count of turns can promise. The test's own timeout is what ends a wait
/// for something that never comes.
Future<void> _until(bool Function() reached) async {
  while (!reached()) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

/// A work directory the test hands over when it chooses, so that a stop can
/// land while a start is still waiting for it.
class _HeldWorkDirectory {
  _HeldWorkDirectory(this.directory);

  final Directory directory;
  final _waiting = Queue<Completer<Directory>>();

  /// How many times it has been asked for.
  int asked = 0;

  Future<Directory> call() {
    asked++;
    final answer = Completer<Directory>();
    _waiting.add(answer);
    return answer.future;
  }

  /// Answers whoever has waited longest.
  void handOver() => _waiting.removeFirst().complete(directory);
}

/// The native library as a start and a stop see it: `ld_start` and `ld_stop`
/// queue the states the real ones do, and the poll hands them out.
class _FakeNative extends Fake implements NativeBridge {
  /// The configs `ld_start` was given, in the order it was given them.
  final started = <Map<String, Object?>>[];

  /// What `ld_start` answers; negative is a capture that would not start.
  int startCode = 0;

  /// What `ld_stop` answers; negative is a library that would not stop.
  int stopCode = 0;
  int stops = 0;
  final _events = Queue<String>();

  @override
  int start(String configJson) {
    started.add(jsonDecode(configJson) as Map<String, Object?>);
    if (startCode < 0) return startCode;
    _events
      ..add('{"type":"state","state":"starting"}')
      ..add('{"type":"state","state":"listening"}');
    return 0;
  }

  /// Queues what the library would report next.
  void push(String event) => _events.add(event);

  @override
  int stop() {
    stops++;
    if (stopCode < 0) return stopCode;
    _events.add('{"type":"state","state":"idle"}');
    return 0;
  }

  @override
  int pollEvent(Pointer<Char> output, int capacity) {
    if (_events.isEmpty) return 0;
    final bytes = utf8.encode(_events.first);
    // Asked how long it is, or handed too little: the event stays queued.
    if (output == nullptr || capacity <= bytes.length) return bytes.length;
    _events.removeFirst();
    output.cast<Uint8>().asTypedList(capacity)
      ..setRange(0, bytes.length, bytes)
      ..[bytes.length] = 0;
    return bytes.length;
  }

  @override
  int setProcessVolume(int processId, double volume) => 0;

  @override
  int restoreProcessVolumes() => 0;

  @override
  String errorMessage(int code) => 'native error $code';
}

/// A worker that comes up at once and answers a line when the test says.
class _HeldInference extends Fake implements LocalInferenceService {
  final asked = <Completer<InferenceResult>>[];

  @override
  void Function(double value, String stage)? onStartupProgress;

  @override
  void Function(LoreDubFailure failure)? onWorkerLost;

  // Where the worker's stages run, which a session's first state reports.
  @override
  ComputeBackend? get translationBackend => null;

  @override
  ComputeBackend? get speechBackend => null;

  @override
  ComputeBackend? get voiceConversionBackend => null;

  @override
  Future<void> start(
    WorkerPlan plan, {
    bool requiresWhisper = false,
    WorkerLoad load = WorkerLoad.full,
  }) async {}

  @override
  Future<InferenceResult> processText(
    String english, {
    String? originalWavePath,
    bool translate = true,
    double? speed,
    String? spoken,
    bool transcript = false,
  }) {
    final answer = Completer<InferenceResult>();
    asked.add(answer);
    return answer.future;
  }

  @override
  Future<void> stop() async {}
}
