// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/screen_reading.dart';
import 'package:lore_dub/src/data/repositories/session_repository.dart';
import 'package:lore_dub/src/data/services/character_service.dart';
import 'package:lore_dub/src/data/services/glossary_service.dart';
import 'package:lore_dub/src/data/services/native_engine_service.dart';
import 'package:lore_dub/src/data/services/pipeline_graph_service.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/built_voice.dart';
import 'package:lore_dub/src/domain/failure.dart';
import 'package:lore_dub/src/domain/game_process.dart';
import 'package:lore_dub/src/domain/pipeline_graph.dart';
import 'package:lore_dub/src/domain/voice_files.dart';
import 'package:lore_dub/src/domain/session_config.dart';

void main() {
  late _SlowEngine engine;
  late _SlowGlossary glossary;
  late SessionRepository repository;

  setUp(() {
    engine = _SlowEngine();
    glossary = _SlowGlossary();
    repository = SessionRepository(engine, _Characters(), glossary, _Graph());
  });

  /// The start with the least to it: the converter alone, and no game. It
  /// answers with the number of the session it began.
  const worker = WorkerPlan(
    threads: 2,
    pythonExecutable: 'python.exe',
    runtimeDirectory: 'runtime',
    speaker: 'aidar',
  );

  Future<int> start() => repository.startVoiceFiles(worker);

  const game = GameProcess(pid: 42, name: 'game.exe', path: r'C:\game.exe');

  /// Live dubbing, whose config is written out — the glossary among it —
  /// before the engine is called.
  Future<void> dub({AppSettings settings = const AppSettings()}) => repository.start(
    process: game,
    settings: settings,
    worker: worker,
    translateSpeech: true,
  );

  Future<void> readScreen({
    ScreenReading reading = ScreenReading.both,
    bool hearsVoices = false,
  }) => repository.startScreenText(
    reading: reading,
    hearsVoices: hearsVoices,
    process: game,
    settings: const AppSettings(),
    worker: hearsVoices
        ? const WorkerPlan(
            threads: 2,
            pythonExecutable: 'python.exe',
            runtimeDirectory: 'runtime',
            revoice: true,
            voiceBank: 'voice_bank/game.json',
          )
        : worker,
  );

  Matcher failsWith(FailureCode code) =>
      throwsA(isA<LoreDubFailure>().having((failure) => failure.code, 'code', code));

  group('what a reading of the screen captures and which keys it takes', () {
    /// Lets a start through, once it has got as far as the engine: the
    /// screen session writes its glossary and its cast out first.
    Future<void> began(Future<void> started) async {
      glossary.written.complete('glossary.session.json');
      for (var turn = 0; engine.starts.isEmpty && turn < 1000; turn++) {
        await Future<void>.delayed(Duration.zero);
      }
      engine.starts.last.complete();
      await started;
    }

    test('both: the frame is scanned and either key is registered', () async {
      await began(readScreen());

      expect(engine.screen!.capture.mode, CaptureMode.ocr);
      expect(engine.snapshotKey, isNotNull);
      expect(engine.frameKey, isNotNull);
    });

    test('names the game, whose window the frame is read out of', () async {
      // Without it the native start refuses a reading of the window
      // outright, and the game is never turned down under a line.
      await began(readScreen());

      expect(engine.screen!.capture.processId, game.pid);
    });

    test('snippets: nothing is captured until the key is pressed', () async {
      await began(readScreen(reading: ScreenReading.snippets));

      expect(engine.screen!.capture.mode, CaptureMode.none);
      expect(engine.snapshotKey, isNotNull);
      expect(engine.frameKey, isNull, reason: 'there is no frame to redraw');
    });

    test('following the voices, the game is listened to as well', () async {
      await began(readScreen(reading: ScreenReading.subtitles, hearsVoices: true));

      expect(engine.screen!.capture.mode, CaptureMode.ocrAndAudio);
      expect(engine.screen!.worker.revoice, isTrue, reason: 'the timbre is carried over');
      expect(engine.screen!.worker.voiceBank, isNotNull, reason: 'the game keeps its voices');
    });

    test('subtitles: the frame is scanned and the key is left alone', () async {
      await began(readScreen(reading: ScreenReading.subtitles));

      expect(engine.screen!.capture.mode, CaptureMode.ocr);
      expect(engine.snapshotKey, isNull, reason: 'nothing is picked out by hand');
      expect(engine.frameKey, isNotNull);
    });
  });

  test('adds the files it keeps to the worker it is handed, and nothing else', () async {
    final started = dub();
    glossary.written.complete('glossary.session.json');
    for (var turn = 0; engine.starts.isEmpty && turn < 1000; turn++) {
      await Future<void>.delayed(Duration.zero);
    }
    engine.starts.last.complete();
    await started;

    final live = engine.live!;
    expect(live.worker.glossary, 'glossary.session.json');
    expect(live.worker.characters, 'characters.json');
    expect(live.worker.asHeard, {'guard'}, reason: 'the cut drawn on the canvas');
    expect(live.worker.speaker, 'aidar', reason: 'the rest is what it was handed');
    expect(live.capture.processId, game.pid);
  });

  test('clears away what a failed start left behind', () async {
    final starting = expectLater(start(), failsWith(FailureCode.workerStartTimeout));

    engine.starts.single.completeError(const LoreDubFailure(FailureCode.workerStartTimeout));
    await starting;

    expect(engine.stops, 1);
  });

  test('leaves a newer session alone when the start it replaced fails at last', () async {
    final replaced = expectLater(start(), failsWith(FailureCode.pipelineStopped));
    final current = start();

    // Minutes later, as a start nobody ended used to: into whichever session
    // was running by then.
    engine.starts.first.completeError(TimeoutException('Future not completed'));
    await replaced;

    expect(engine.stops, 0, reason: 'the engine holds a session that is not this start\'s to end');
    engine.starts.last.complete();
    await current;
  });

  test('ends a start the player stopped as stopped, whatever it failed with', () async {
    final stopped = expectLater(start(), failsWith(FailureCode.pipelineStopped));

    await repository.stop();
    engine.starts.single.completeError(StateError('the pipe closed under it'));
    await stopped;

    expect(engine.stops, 1, reason: 'the stop that was asked for, and not a second one');
  });

  test('ends a start stopped as its engine came up as stopped', () async {
    final stopped = expectLater(start(), failsWith(FailureCode.pipelineStopped));

    engine.starts.single.complete();
    // Before the start hears that its engine is up.
    final stopping = repository.stop();
    await stopped;
    await stopping;

    expect(engine.stops, 1, reason: 'the stop that was asked for, and not a second one');
  });

  group('a stop landing while the config is still written out', () {
    for (final (name, begin) in [('live dubbing', dub), ('the screen session', readScreen)]) {
      test('keeps $name from reaching the engine at all', () async {
        final stopped = expectLater(begin(), failsWith(FailureCode.pipelineStopped));

        await repository.stop();
        glossary.written.complete('glossary.session.json');
        await stopped;

        expect(engine.starts, isEmpty, reason: 'no worker and no capture for a stopped session');
        expect(engine.stops, 1, reason: 'the stop that was asked for, and not a second one');
        expect(engine.hotkeys, 0);
      });
    }

    test('leaves the start that replaced it to run', () async {
      final replaced = expectLater(dub(), failsWith(FailureCode.pipelineStopped));
      final current = start();

      glossary.written.complete('glossary.session.json');
      await replaced;
      engine.starts.single.complete();
      await current;

      expect(engine.starts, hasLength(1), reason: 'only the newer start reached the engine');
      expect(engine.stops, 0);
    });
  });

  group('a stop landing once the engine has come up', () {
    test('registers no hotkeys for the session it ended', () async {
      glossary.written.complete('glossary.session.json');
      final stopped = expectLater(dub(), failsWith(FailureCode.pipelineStopped));
      await pumpEventQueue();

      engine.starts.single.complete();
      // Before the start hears that its engine is up.
      final stopping = repository.stop();
      await stopped;
      await stopping;

      expect(engine.hotkeys, 0, reason: 'ld_stop dropped them, and nothing may bring them back');
      expect(engine.stops, 1, reason: 'the stop has ended the engine; the start must not again');
    });

    test('and not landing at all lets the session run whole', () async {
      glossary.written.complete('glossary.session.json');
      final running = dub();
      await pumpEventQueue();
      engine.starts.single.complete();
      await running;

      expect(engine.hotkeys, 1);
      expect(engine.stops, 0);
    });
  });

  group('a session that was borrowed', () {
    /// A start that came up, and the number it answered with.
    Future<int> borrow() {
      final borrowing = start();
      engine.starts.last.complete();
      return borrowing;
    }

    test('is put down while it is still the one the engine holds', () async {
      final borrowed = await borrow();

      await repository.stopSession(borrowed);

      expect(engine.stops, 1);
    });

    test('is left alone once another session has replaced it', () async {
      final borrowed = await borrow();
      // Live starting takes the worker over, and asks nobody.
      await borrow();

      await repository.stopSession(borrowed);

      expect(engine.stops, 0, reason: 'what the engine holds by now is somebody else\'s');
    });

    test('is not stopped a second time once it has been stopped', () async {
      final borrowed = await borrow();
      await repository.stop();
      // Whatever started since is not this number's to end either.
      final current = await borrow();

      await repository.stopSession(borrowed);

      expect(engine.stops, 1, reason: 'the stop that was asked for, and no other');
      await repository.stopSession(current);
      expect(engine.stops, 2);
    });
  });

  group('files a card is built from', () {
    Future<void> borrow() async {
      final borrowing = start();
      engine.starts.last.complete();
      await borrowing;
    }

    test('are measured through the session they were handed to', () async {
      await borrow();

      final building = repository.buildVoice(['line.ogg']);
      engine.decoding.single.complete(engine.files);

      expect((await building).used, 1);
      expect(engine.measured, [engine.files]);
      expect(engine.discarded, isEmpty);
    });

    test('are dropped unmeasured once Live has taken the worker over', () async {
      await borrow();

      final building = expectLater(
        repository.buildVoice(['line.ogg']),
        failsWith(FailureCode.pipelineStopped),
      );
      // Live stops the session the files were meant for and starts its own
      // while they are still being decoded.
      await repository.stop();
      await borrow();
      engine.decoding.single.complete(engine.files);
      await building;

      expect(engine.measured, isEmpty, reason: 'the worker is the dubbing\'s by now');
      expect(engine.discarded, [engine.files], reason: 'the decoded files are not left behind');
    });
  });
}

/// An engine whose starts end when the test says so, the way a real one ends
/// minutes after it was asked.
class _SlowEngine extends Fake implements NativeEngineService {
  final starts = <Completer<void>>[];
  int stops = 0;
  int hotkeys = 0;

  /// The processes turned down, and — when set — the wait that takes.

  Future<void> _starting() {
    final starting = Completer<void>();
    starts.add(starting);
    return starting.future;
  }

  /// What the last live session was started with.
  LiveSessionConfig? live;

  @override
  Future<void> start(LiveSessionConfig config) {
    live = config;
    return _starting();
  }

  /// What the last screen session was started with, and which keys it
  /// asked for.
  ScreenSessionConfig? screen;
  Hotkey? snapshotKey;
  Hotkey? frameKey;

  @override
  Future<void> startScreenText(ScreenSessionConfig config) {
    screen = config;
    return _starting();
  }

  @override
  Future<void> startVoiceFiles(VoiceFilesSessionConfig config) => _starting();

  @override
  void setHotkeys({
    Hotkey? pause,
    Hotkey? resume,
    Hotkey? snapshot,
    Hotkey? frame,
    Hotkey? frameOverlay,
    int frameOf = 0,
    String textLanguage = 'en',
  }) {
    hotkeys++;
    snapshotKey = snapshot;
    frameKey = frame;
  }

  @override
  Future<void> stop() async => stops++;

  /// The files every decoding answers with, once the test lets it finish.
  final files = const VoiceFiles(decoded: {'dropped_0.wav': 'line.ogg'});
  final decoding = <Completer<VoiceFiles>>[];
  final measured = <VoiceFiles>[];
  final discarded = <VoiceFiles>[];

  @override
  Future<VoiceFiles> decodeVoiceFiles(List<String> paths) {
    final decoded = Completer<VoiceFiles>();
    decoding.add(decoded);
    return decoded.future;
  }

  @override
  Future<BuiltVoice> measureVoiceFiles(VoiceFiles files) async {
    measured.add(files);
    return const BuiltVoice(vector: [1], used: 1);
  }

  @override
  Future<void> discardVoiceFiles(VoiceFiles files, {String? keeping}) async => discarded.add(files);
}

/// A glossary whose session file is written when the test says so: the one
/// wait a start makes before it calls the engine that a test can hold.
class _SlowGlossary extends Fake implements GlossaryService {
  final written = Completer<String>();

  @override
  Future<String> sessionFile() => written.future;
}

class _Characters extends Fake implements CharacterService {
  @override
  Future<String> file() async => 'characters.json';
}

class _Graph extends Fake implements PipelineGraphService {
  @override
  Future<PipelineLayout> load() async => const PipelineLayout(silent: {'guard'});
}
