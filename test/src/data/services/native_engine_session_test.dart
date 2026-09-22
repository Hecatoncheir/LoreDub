// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:collection';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/local_inference_service.dart';
import 'package:lore_dub/src/data/services/native_bridge.dart';
import 'package:lore_dub/src/data/services/native_engine_service.dart';
import 'package:lore_dub/src/data/services/worker_arguments.dart';
import 'package:lore_dub/src/domain/built_voice.dart';
import 'package:lore_dub/src/domain/compute_device.dart';
import 'package:lore_dub/src/domain/engine_event.dart';
import 'package:lore_dub/src/domain/failure.dart';
import 'package:lore_dub/src/domain/glossary.dart';
import 'package:lore_dub/src/domain/hotkey.dart';
import 'package:lore_dub/src/domain/ocr_region.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart';
import 'package:lore_dub/src/domain/session_config.dart';
import 'package:lore_dub/src/domain/voice_files.dart';
import 'package:path/path.dart' as path;

import '../../../support/temporary_directory.dart';

/// What a running session does with what the library and the worker tell
/// it: a line off the screen, the voice heard beside it, a frame redrawn,
/// a selection, a pause, the keys, a card's take and the files of one.
void main() {
  const worker = WorkerPlan(
    threads: 2,
    pythonExecutable: 'python.exe',
    runtimeDirectory: 'rt',
    speaker: 'xenia',
  );

  late Directory work;
  late _Native native;
  late _Worker inference;
  late NativeEngineService engine;
  late List<EngineEvent> events;

  setUp(() async {
    work = await Directory.systemTemp.createTemp('lore-dub-session');
    addTearDown(() => deleteOnceReleased(work));
    native = _Native();
    inference = _Worker();
    engine = NativeEngineService(
      inference: inference,
      native: native,
      workDirectory: () async => work,
    );
    events = [];
    engine.events.listen(events.add);
  });

  tearDown(() => engine.stop());

  /// A recording the capture cut, on disk where the library would put it.
  File segment(String name) => File(path.join(work.path, name))..writeAsBytesSync([0, 1]);

  /// Hands [event] to the engine the way the library does, and waits for it
  /// to have been read.
  Future<void> say(Map<String, Object?> event) async {
    native.push(jsonEncode(event));
    await _until(() => native.queued == 0);
    await pumpEventQueue();
  }

  Future<void> screen({bool voices = false}) => engine.startScreenText(
    ScreenSessionConfig(
      worker: worker,
      capture: CapturePlan(mode: voices ? CaptureMode.ocrAndAudio : CaptureMode.ocr, processId: 7),
      lines: const LineRules(targetLanguage: 'ru'),
    ),
  );

  group('reading the screen', () {
    test('voices what a line gained, and not a line that came back unchanged', () async {
      await screen();

      await say({'type': 'ocrText', 'text': 'The gate is sealed.'});
      await say({'type': 'ocrText', 'text': 'The gate is sealed.'});
      await say({'type': 'ocrText', 'text': 'The gate is sealed. Find the key.'});

      expect(inference.texts, ['The gate is sealed.', 'Find the key.']);
      expect(events.whereType<LineDubbed>(), hasLength(2));
    });

    test('forgets the old frame\'s text when the frame is drawn anew', () async {
      await screen();
      await say({'type': 'ocrText', 'text': 'Hello there.'});

      await say({'type': 'subtitleFrame', 'left': 0.1, 'top': 0.6, 'right': 0.9, 'bottom': 1});
      await say({'type': 'ocrText', 'text': 'Hello there.'});

      final moved = events.whereType<SubtitleFrameMoved>().single;
      expect(moved.region, const OcrRegion(left: 0.1, top: 0.6, right: 0.9, bottom: 1));
      expect(inference.texts, ['Hello there.', 'Hello there.'], reason: 'the new frame read it');
    });

    test('says so when a frame was drawn beside the game', () async {
      await screen();

      await say({'type': 'subtitleFrame', 'failed': true});

      expect(events.whereType<SubtitleFrameMoved>().single.region, isNull);
    });

    test('reads a selection as one line, and says what it read', () async {
      await screen();

      await say({'type': 'snapshot', 'text': 'Press   F\nto pay respects'});

      expect(events.whereType<SnapshotRead>().single.text, 'Press F to pay respects');
      await _until(() => inference.texts.isNotEmpty);
      expect(inference.texts.single, 'Press F to pay respects');
    });

    test('a selection that held nothing is said and not read', () async {
      await screen();

      await say({'type': 'snapshot', 'text': '', 'failed': true});

      expect(events.whereType<SnapshotRead>().single.failed, isTrue);
      expect(inference.texts, isEmpty);
    });

    test('colours a line with the voice heard as it appeared, and lets the last one go', () async {
      await screen(voices: true);
      final first = segment('first.wav');
      final second = segment('second.wav');

      await say({'type': 'audioSegment', 'path': first.path});
      await say({'type': 'audioSegment', 'path': second.path});
      expect(first.existsSync(), isFalse, reason: 'no line was waiting to be read in it');

      await say({'type': 'ocrText', 'text': 'Run!'});
      await _until(() => inference.heard.isNotEmpty);
      expect(inference.heard.single, second.path);
      expect(second.existsSync(), isTrue, reason: 'still the voice of the moment');
    });

    test('says nothing of text once the session rests', () async {
      await screen();
      engine.setPaused(true);

      await say({'type': 'ocrText', 'text': 'Quiet.'});

      expect(inference.texts, isEmpty);
      expect(native.paused, [true]);
    });
  });

  group('a running session', () {
    Future<void> live() => engine.start(
      const LiveSessionConfig(
        worker: worker,
        capture: CapturePlan(mode: CaptureMode.audio, processId: 7),
        lines: LineRules(targetLanguage: 'ru', duckVolume: 0.3),
      ),
    );

    test('rests and wakes without being torn down, the game let up meanwhile', () async {
      await live();
      expect(native.volumes, [(7, 0.3)]);

      engine.setPaused(true);
      final heard = segment('heard.wav');
      await say({'type': 'audioSegment', 'path': heard.path});
      await _until(() => !heard.existsSync());
      engine.setPaused(false);

      expect(native.paused, [true, false]);
      expect(native.restored, 1, reason: 'the game at its own volume while the dubbing rests');
      expect(native.volumes, [(7, 0.3), (7, 0.3)]);
      expect(native.stops, 0);
    });

    test('with nothing running, a pause asks nothing of the library', () {
      engine.setPaused(true);

      expect(native.paused, isEmpty);
    });

    test('reads the lines that follow in a new voice, once', () async {
      await live();

      await engine.useVoice('baya');
      await engine.useVoice('baya');

      expect(inference.voices, ['baya']);
    });

    test('passes what the canvas and the glossary say on to the worker', () async {
      await live();

      await engine.readAsHeard({'guard'});
      await engine.voiceCharacterAs('guard', 'smith');
      await engine.writeGlossary(Glossary.empty);

      expect(inference.asHeard, [
        {'guard'},
      ]);
      expect(inference.voicedBy, [('guard', 'smith')]);
      expect(inference.glossaries, 1);
    });

    test('a worker lost under it is said, and the session ended', () async {
      await live();

      inference.onWorkerLost!(const LoreDubFailure(FailureCode.workerExitedSilently));
      await _until(() => native.stops == 1);

      expect(events.whereType<EngineFailed>(), hasLength(1));
    });
  });

  group('the keys and the frame', () {
    test('register every combination, flat, as the library reads them', () {
      engine.setHotkeys(
        pause: const Hotkey(keyCode: 0x50, label: 'P', control: true),
        snapshot: const Hotkey(keyCode: 0x53, label: 'S', alt: true),
        frameOf: 7,
        textLanguage: 'ru',
      );

      final keys = native.hotkeys.single;
      expect(keys['pauseKey'], 0x50);
      expect(keys['pauseModifiers'], isNonZero);
      expect(keys['snapshotKey'], 0x53);
      expect(keys['resumeKey'], 0, reason: 'unbound');
      expect(keys['frameProcessId'], 7);
      expect(keys['snapshotLanguage'], 'ru');
    });

    test('draw the frame over the game and take it off', () {
      engine
        ..showFrame(
          processId: 7,
          region: const OcrRegion(left: 0.2, top: 0.5, right: 0.8, bottom: 1),
        )
        ..hideFrame();

      expect(native.frames.single, {
        'processId': 7,
        'ocrRegionLeft': 0.2,
        'ocrRegionTop': 0.5,
        'ocrRegionRight': 0.8,
        'ocrRegionBottom': 1.0,
      });
      expect(native.hidden, 1);
    });

    test('a combination the library refuses is a failure with its words', () {
      native.hotkeyCode = -3;

      expect(
        () => engine.setHotkeys(pause: const Hotkey(keyCode: 0x50, label: 'P')),
        throwsA(
          isA<LoreDubFailure>().having((f) => f.code, 'code', FailureCode.nativeCallFailed),
        ),
      );
    });
  });

  group('the machine', () {
    test('lists the processes, the monitors and the adapters it reports', () async {
      native
        ..processes = jsonEncode([
          {'pid': 2, 'name': 'b.exe', 'path': r'C:\b.exe'},
          {'pid': 1, 'name': 'a.exe', 'path': r'C:\a.exe'},
        ])
        ..monitors = jsonEncode([
          {'left': 0, 'top': 0, 'right': 1920, 'bottom': 1080, 'primary': true},
        ])
        ..graphics = jsonEncode({
          'adapters': [
            {'name': 'RTX', 'vendorId': 4318, 'dedicatedMemory': 12000000000},
          ],
          'cudaDriver': true,
        });

      final processes = await engine.listProcesses();
      final layout = await engine.monitorLayout();
      final machine = await engine.probeGraphics();

      expect(processes.map((process) => process.name).toSet(), {'a.exe', 'b.exe'});
      expect(layout.monitors.single.primary, isTrue);
      expect(machine.cudaDriver, isTrue);
      expect(machine.adapters.single.name, 'RTX');
    });
  });

  group('a card', () {
    test('keeps what it hears only while a take is open', () async {
      await engine.startCharacters(
        const CharactersSessionConfig(
          worker: worker,
          capture: CapturePlan(mode: CaptureMode.audio, processId: 7),
        ),
      );
      final between = segment('between.wav');
      await say({'type': 'audioSegment', 'path': between.path});
      await _until(() => !between.existsSync());
      expect(inference.fingerprinted, isEmpty, reason: 'nobody is recording');

      await engine.setRecordingVoice(recording: true);
      // Letting go waits for the recording the take leaves behind.
      final closing = engine.setRecordingVoice(recording: false);
      final take = segment('take.wav');
      await say({'type': 'audioSegment', 'path': take.path});
      await closing;

      expect(inference.fingerprinted, [take.path]);
      expect(native.holds.take(2), [1, 0]);
      expect(events.whereType<CharacterVoiceMeasured>().single.clip, take.path);
    });

    test('built from files names the ones it skipped as the player dropped them', () async {
      await engine.startVoiceFiles(const VoiceFilesSessionConfig(worker: worker));
      await pumpEventQueue();
      expect(
        events.whereType<SessionStateChanged>().single.status,
        PipelineStatus.listening,
        reason: 'nothing native starts to say so',
      );
      final kept = segment('dropped_0.wav');
      final odd = segment('dropped_1.wav');
      inference.built = BuiltVoice(used: 1, skipped: [odd.path], anchor: kept.path);

      final voice = await engine.measureVoiceFiles(
        VoiceFiles(
          decoded: {kept.path: r'C:\hero.ogg', odd.path: r'C:\noise.ogg'},
          unreadable: const [r'C:\broken.ogg'],
        ),
      );

      expect(voice.skipped, [r'C:\broken.ogg', r'C:\noise.ogg']);
      expect(kept.existsSync(), isTrue, reason: 'the card copies the clip it stands closest to');
      expect(odd.existsSync(), isFalse);
    });

    test('a sample comes up with the voice and nothing native', () async {
      await engine.startPreview(const PreviewSessionConfig(worker: worker));

      expect(native.started, isEmpty);
      expect(inference.loads.single, WorkerLoad.speechOnly);
    });
  });
}

Future<void> _until(bool Function() done) async {
  for (var turn = 0; !done(); turn++) {
    if (turn > 500) fail('never came to pass');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// The library, answering from memory and writing down what it was asked.
class _Native extends NativeBridge {
  final started = <Map<String, Object?>>[];
  final hotkeys = <Map<String, Object?>>[];
  final frames = <Map<String, Object?>>[];
  final paused = <bool>[];
  final holds = <int>[];
  final volumes = <(int, double)>[];
  int hidden = 0;
  int stops = 0;
  int restored = 0;
  int hotkeyCode = 0;
  String processes = '[]';
  String monitors = '[]';
  String graphics = '{}';
  final _events = Queue<String>();

  int get queued => _events.length;

  void push(String event) => _events.add(event);

  @override
  int start(String configJson) {
    started.add(jsonDecode(configJson) as Map<String, Object?>);
    _events.add('{"type":"state","state":"listening"}');
    return 0;
  }

  @override
  int stop() {
    stops++;
    return 0;
  }

  @override
  int pollEvent(Pointer<Char> output, int capacity) {
    if (_events.isEmpty) return 0;
    final bytes = utf8.encode(_events.first);
    if (output == nullptr || capacity <= bytes.length) return bytes.length;
    _events.removeFirst();
    output.cast<Uint8>().asTypedList(capacity)
      ..setRange(0, bytes.length, bytes)
      ..[bytes.length] = 0;
    return bytes.length;
  }

  @override
  int setPaused({required bool paused}) {
    this.paused.add(paused);
    return 0;
  }

  @override
  int setHotkeys(String configJson) {
    hotkeys.add(jsonDecode(configJson) as Map<String, Object?>);
    return hotkeyCode;
  }

  @override
  int showFrame(String configJson) {
    frames.add(jsonDecode(configJson) as Map<String, Object?>);
    return 0;
  }

  @override
  int hideFrame() {
    hidden++;
    return 0;
  }

  @override
  int holdTake(int hold) {
    holds.add(hold);
    // A take that gathered something, so closing it waits to be measured.
    return hold == 0 ? 1000 : 0;
  }

  @override
  int setProcessVolume(int processId, double volume) {
    volumes.add((processId, volume));
    return 0;
  }

  @override
  int restoreProcessVolumes() {
    restored++;
    return 0;
  }

  @override
  String processesJson() => processes;

  @override
  String monitorsJson() => monitors;

  @override
  String graphicsJson() => graphics;

  @override
  String errorMessage(int code) => 'native error $code';
}

/// A worker that is up at once and answers every line as silenced, so
/// nothing reaches the sound device.
class _Worker extends Fake implements LocalInferenceService {
  final texts = <String>[];
  final heard = <String>[];
  final voices = <String>[];
  final asHeard = <Set<String>>[];
  final voicedBy = <(String, String?)>[];
  final fingerprinted = <String>[];
  final loads = <WorkerLoad>[];
  int glossaries = 0;
  BuiltVoice built = const BuiltVoice();

  @override
  void Function(double value, String stage)? onStartupProgress;

  @override
  void Function(LoreDubFailure failure)? onWorkerLost;

  @override
  ComputeBackend? get translationBackend => ComputeBackend.cpu;

  @override
  ComputeBackend? get speechBackend => null;

  @override
  ComputeBackend? get voiceConversionBackend => null;

  @override
  Future<void> start(
    WorkerPlan plan, {
    bool requiresWhisper = false,
    WorkerLoad load = WorkerLoad.full,
  }) async => loads.add(load);

  @override
  Future<void> stop() async {}

  @override
  Future<InferenceResult> processText(
    String english, {
    String? originalWavePath,
    bool translate = true,
    double? speed,
  }) async {
    texts.add(english);
    if (originalWavePath != null) heard.add(originalWavePath);
    return InferenceResult(english: english, translated: '', wavePath: null, silenced: true);
  }

  @override
  Future<({List<double> vector, String? gender, double seconds})> fingerprint(
    String wavePath,
  ) async {
    fingerprinted.add(wavePath);
    return (vector: [0.5], gender: 'male', seconds: 2.0);
  }

  @override
  Future<BuiltVoice> buildVoice(List<String> wavePaths) async => built;

  @override
  Future<void> useVoice(String voice) async => voices.add(voice);

  @override
  Future<void> readAsHeard(Set<String> value) async => asHeard.add(value);

  @override
  Future<void> voiceCharacterAs(String character, String? target) async =>
      voicedBy.add((character, target));

  @override
  Future<void> updateGlossary(Glossary glossary) async => glossaries++;
}
