// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/engine_session.dart';
import 'package:lore_dub/src/data/services/local_inference_service.dart';
import 'package:lore_dub/src/data/services/phrase_processor.dart';
import 'package:lore_dub/src/data/services/phrase_queue.dart';
import 'package:lore_dub/src/data/services/voice_take.dart';
import 'package:lore_dub/src/domain/engine_event.dart';
import 'package:lore_dub/src/domain/session_config.dart';
import 'package:lore_dub/src/domain/speech_pace.dart';

import '../../../support/temporary_directory.dart';

void main() {
  const worker = WorkerPlan(
    threads: 3,
    pythonExecutable: 'python.exe',
    runtimeDirectory: 'rt',
    models: ModelPaths(whisper: 'ggml.bin', speech: 'model.onnx'),
  );
  const heard = CapturePlan(mode: CaptureMode.audio, processId: 7);

  late _Inference inference;
  late List<EngineEvent> said;
  late List<(String, String?)> voiced;
  late List<String> discarded;
  late List<String?> released;
  late List<Object> failures;
  late int waiting;
  late EngineSession? run;
  late VoiceTake take;
  late PhraseProcessor processor;

  EngineSession up(SessionConfig config) => run = EngineSession(config)..running = true;

  LiveSessionConfig live({
    WorkerPlan plan = worker,
    LineRules lines = const LineRules(targetLanguage: 'ru'),
  }) => LiveSessionConfig(worker: plan, capture: heard, lines: lines);

  setUp(() {
    inference = _Inference();
    said = [];
    voiced = [];
    discarded = [];
    released = [];
    failures = [];
    waiting = 0;
    run = null;
    take = VoiceTake(hold: (hold) => hold, discard: (path) async => discarded.add(path));
    processor = PhraseProcessor(
      inference,
      run: () => run,
      emit: said.add,
      take: take,
      voice: (wave, {speaker}) => voiced.add((wave, speaker)),
      waiting: () => waiting,
      releaseVoiceHeard: (wave) async => released.add(wave),
      reportFailure: failures.add,
      discard: (path) async => discarded.add(path),
    );
  });

  group('a recorded voice for a card', () {
    setUp(() => up(const CharactersSessionConfig(worker: worker, capture: heard)));

    test('is measured and kept while the take runs', () async {
      take.open();
      inference.fingerprinted = (vector: [0.2, 0.4], gender: 'female', seconds: 2.5);

      await processor.process(PendingPhrase.audio('take.wav'));

      final measured = said.single as CharacterVoiceMeasured;
      expect(measured.vector, [0.2, 0.4]);
      expect(measured.gender, 'female');
      expect(measured.clip, 'take.wav', reason: 'the screen puts it beside the card');
      expect(discarded, isEmpty);
    });

    test('is let go of when measured between takes', () async {
      inference.fingerprinted = (vector: [0.2], gender: null, seconds: 1.0);

      await processor.process(PendingPhrase.audio('late.wav'));

      expect((said.single as CharacterVoiceMeasured).clip, isNull);
      expect(discarded, ['late.wav']);
    });

    test('that held no voice says nothing and is thrown away', () async {
      take.open();
      inference.fingerprinted = (vector: const <double>[], gender: null, seconds: 0.0);

      await processor.process(PendingPhrase.audio('silence.wav'));

      expect(said, isEmpty);
      expect(discarded, ['silence.wav']);
    });

    test('that could not be measured is reported', () async {
      inference.fails = StateError('no converter');

      await processor.process(PendingPhrase.audio('take.wav'));

      expect(failures.single, isA<StateError>());
      expect(discarded, ['take.wav']);
    });
  });

  group('a phrase heard before the dubbing starts', () {
    setUp(() => up(const SceneSessionConfig(worker: worker, capture: heard)));

    test('is placed among the voices of the scene and dropped', () async {
      inference.listened = (speaker: 'timbre:2', seconds: 1.8);

      await processor.process(PendingPhrase.audio('scene.wav'));

      final voice = said.single as SceneVoiceHeard;
      expect(voice.speaker, 'timbre:2');
      expect(voice.seconds, 1.8);
      expect(discarded, ['scene.wav']);
    });

    test('that belongs to nobody adds no row', () async {
      inference.listened = (speaker: null, seconds: 0.4);

      await processor.process(PendingPhrase.audio('cough.wav'));

      expect(said, isEmpty);
      expect(discarded, ['cough.wav']);
    });

    test('that could not be placed is reported', () async {
      inference.fails = StateError('worker gone');

      await processor.process(PendingPhrase.audio('scene.wav'));

      expect(failures, hasLength(1));
      expect(discarded, ['scene.wav']);
    });
  });

  group('a dubbed phrase', () {
    test('is shown, voiced, and names the voice, the bank and the language once', () async {
      final session = up(live());
      inference
        ..answer = const InferenceResult(
          english: 'Hello',
          translated: 'Привет',
          wavePath: 'line.wav',
          voice: 'xenia',
          bankSize: 3,
          speaker: 'timbre:1',
        )
        ..spoken = 'en';

      await processor.process(PendingPhrase.audio('segment.wav'));
      await processor.process(PendingPhrase.audio('again.wav'));

      final lines = said.whereType<LineDubbed>().toList();
      expect(lines, hasLength(2));
      expect(lines.first.line.translated, 'Привет');
      expect(lines.first.line.speaker, 'timbre:1');
      expect(lines.first.line.spoken, 'line.wav');
      expect(said.whereType<VoiceSpoken>().single.name, 'xenia');
      expect(said.whereType<VoiceBankGrew>().single.size, 3);
      expect(said.whereType<LanguageDetected>().single.code, 'en');
      expect(session.reportedVoice, 'xenia');
      expect(voiced, [('line.wav', 'timbre:1'), ('line.wav', 'timbre:1')]);
      expect(discarded, ['segment.wav', 'again.wav']);
      expect(inference.segments.first.threads, 3);
    });

    test('recognized as nothing is only thrown away', () async {
      up(live());

      await processor.process(PendingPhrase.audio('noise.wav'));

      expect(said.whereType<LineDubbed>(), isEmpty);
      expect(discarded, ['noise.wav']);
    });

    test('the player silenced is shown and never voiced', () async {
      up(live());
      inference.answer = const InferenceResult(
        english: 'Reloading!',
        translated: '',
        wavePath: null,
        silenced: true,
      );

      await processor.process(PendingPhrase.audio('reload.wav'));

      expect((said.single as LineDubbed).line.silenced, isTrue);
      expect(voiced, isEmpty);
    });

    test('finishing during a pause is shown and not voiced', () async {
      up(live()).paused = true;
      inference.answer = const InferenceResult(english: 'a', translated: 'б', wavePath: 'b.wav');

      await processor.process(PendingPhrase.audio('late.wav'));

      expect(said.whereType<LineDubbed>(), hasLength(1));
      expect(voiced, isEmpty);
      expect(discarded, containsAll(['late.wav', 'b.wav']));
    });

    test('answered after its run ended is dropped with its reading', () async {
      up(live());
      inference
        ..answer = const InferenceResult(english: 'a', translated: 'б', wavePath: 'b.wav')
        ..whileAsked = () => up(live());

      await processor.process(PendingPhrase.audio('old.wav'));

      expect(said.whereType<LineDubbed>(), isEmpty, reason: 'the new session never heard it');
      expect(voiced, isEmpty);
      expect(discarded, containsAll(['old.wav', 'b.wav']));
    });

    test('with no run up does nothing but let the recording go', () async {
      await processor.process(PendingPhrase.audio('orphan.wav'));

      expect(inference.segments, isEmpty);
      expect(discarded, ['orphan.wav']);
    });

    test('that fails is reported and let go of', () async {
      up(live());
      inference.fails = StateError('whisper crashed');

      await processor.process(PendingPhrase.audio('segment.wav'));

      expect(failures, hasLength(1));
      expect(discarded, ['segment.wav']);
    });

    test('is read faster while lines queue for the voice', () async {
      up(live(lines: const LineRules(targetLanguage: 'ru', speed: 1.1, hurryWhenQueued: true)));
      waiting = 4;

      await processor.process(PendingPhrase.audio('segment.wav'));

      expect(inference.segments.single.speed, hurriedSpeed(1.1, 4));
    });

    test('into English is not translated', () async {
      up(live(lines: const LineRules(targetLanguage: 'en')));

      await processor.process(PendingPhrase.audio('segment.wav'));

      expect(inference.segments.single.translate, isFalse);
    });
  });

  group('a phrase of two speakers', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('phrase-processor');
      addTearDown(() => deleteOnceReleased(directory));
      up(live(plan: worker.copyWithConverter('converter')));
    });

    Future<String> recording(double seconds) async {
      final file = File('${directory.path}${Platform.pathSeparator}segment.wav');
      await file.writeAsBytes(_wave(seconds));
      return file.path;
    }

    test('is cut where the voice changes, and each half dubbed on its own', () async {
      final path = await recording(4);
      inference.cuts = [2.0];

      await processor.process(PendingPhrase.audio(path));

      final pieces = inference.segments.map((asked) => asked.wavePath).toList();
      expect(pieces, hasLength(2));
      expect(pieces.every((piece) => File(piece).existsSync()), isTrue);
      expect(discarded, [path, ...pieces], reason: 'the whole goes once it is cut');
    });

    test('with nowhere to cut is dubbed whole', () async {
      final path = await recording(4);

      await processor.process(PendingPhrase.audio(path));

      expect(inference.segments.single.wavePath, path);
    });

    test('nobody could split is reported and dubbed whole', () async {
      final path = await recording(4);
      inference.cutsFail = StateError('diarization failed');

      await processor.process(PendingPhrase.audio(path));

      expect(failures, hasLength(1));
      expect(inference.segments.single.wavePath, path);
    });
  });

  group('text off the screen', () {
    ScreenSessionConfig screen({String textLanguage = 'en'}) => ScreenSessionConfig(
      worker: worker,
      capture: const CapturePlan(mode: CaptureMode.ocr, processId: 7),
      lines: LineRules(targetLanguage: 'ru', textLanguage: textLanguage),
    );

    test('is translated, voiced with the voice heard, and the voice let go', () async {
      up(screen());
      inference.answer = const InferenceResult(
        english: 'Go',
        translated: 'Иди',
        wavePath: 'go.wav',
      );

      await processor.process(PendingPhrase.text('Go', heardWave: 'heard.wav'));

      expect(inference.texts.single.text, 'Go');
      expect(inference.texts.single.originalWavePath, 'heard.wav');
      expect(inference.texts.single.translate, isTrue);
      expect((said.single as LineDubbed).line.original, 'Go');
      expect(voiced.single.$1, 'go.wav');
      expect(released, ['heard.wav']);
    });

    test('in the dubbing language is voiced as it is', () async {
      up(screen(textLanguage: 'ru'));

      await processor.process(PendingPhrase.text('Привет'));

      expect(inference.texts.single.translate, isFalse);
    });

    test('that is only a sound caption answers a selection with nothing', () async {
      up(screen());

      await processor.process(PendingPhrase.text('[Music]', snapshot: true));

      expect(inference.texts, isEmpty);
      expect((said.single as SnapshotRead).text, isEmpty);
    });

    test('a selection is voiced even while the dubbing rests', () async {
      up(screen()).paused = true;
      inference.answer = const InferenceResult(english: 'a', translated: 'б', wavePath: 'b.wav');

      await processor.process(PendingPhrase.text('a', snapshot: true));

      expect((said.single as LineDubbed).snapshot, isTrue);
      expect(voiced.single.$1, 'b.wav');
    });

    test('that fails is reported and still lets the voice go', () async {
      up(screen());
      inference.fails = StateError('worker gone');

      await processor.process(PendingPhrase.text('a', heardWave: 'heard.wav'));

      expect(failures, hasLength(1));
      expect(released, ['heard.wav']);
    });
  });
}

extension on WorkerPlan {
  WorkerPlan copyWithConverter(String converter) => WorkerPlan(
    threads: threads,
    pythonExecutable: pythonExecutable,
    runtimeDirectory: runtimeDirectory,
    models: ModelPaths(whisper: models.whisper, speech: models.speech, converter: converter),
  );
}

/// A mono 16-bit recording at 16 kHz, [seconds] long.
Uint8List _wave(double seconds) {
  const rate = 16000;
  final frames = (rate * seconds).round();
  final wave = Uint8List(44 + frames * 2);
  final bytes = ByteData.sublistView(wave);
  void tag(int offset, String name) => wave.setRange(offset, offset + name.length, name.codeUnits);
  tag(0, 'RIFF');
  bytes.setUint32(4, 36 + frames * 2, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  bytes
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, rate, Endian.little)
    ..setUint32(28, rate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  tag(36, 'data');
  bytes.setUint32(40, frames * 2, Endian.little);
  return wave;
}

/// The worker, answering whatever the test sets.
class _Inference extends Fake implements LocalInferenceService {
  InferenceResult? answer;
  Error? fails;
  String? spoken;
  List<double> cuts = const [];
  Error? cutsFail;
  ({List<double> vector, String? gender, double seconds}) fingerprinted = (
    vector: const <double>[],
    gender: null,
    seconds: 0.0,
  );
  ({String? speaker, double seconds}) listened = (speaker: null, seconds: 0.0);

  /// Runs while a line is being worked on, as a stop and a new start would.
  void Function()? whileAsked;

  final segments = <({String wavePath, int threads, bool translate, double? speed})>[];
  final texts = <({String text, String? originalWavePath, bool translate})>[];

  @override
  String? get spokenLanguage => spoken;

  @override
  Future<({List<double> vector, String? gender, double seconds})> fingerprint(
    String wavePath,
  ) async {
    if (fails case final error?) throw error;
    return fingerprinted;
  }

  @override
  Future<({String? speaker, double seconds})> listenSpeaker(String wavePath) async {
    if (fails case final error?) throw error;
    return listened;
  }

  @override
  Future<List<double>> speakerCuts(String wavePath) async {
    if (cutsFail case final error?) throw error;
    return cuts;
  }

  @override
  Future<InferenceResult?> processSegment({
    required String wavePath,
    required String whisperModel,
    required int threads,
    bool translateSpeech = true,
    double? speed,
    bool translate = true,
    bool roughRecognition = false,
  }) async {
    segments.add((wavePath: wavePath, threads: threads, translate: translate, speed: speed));
    if (fails case final error?) throw error;
    whileAsked?.call();
    return answer;
  }

  @override
  Future<InferenceResult> processText(
    String english, {
    String? originalWavePath,
    bool translate = true,
    double? speed,
    String? spoken,
    bool transcript = false,
  }) async {
    texts.add((text: english, originalWavePath: originalWavePath, translate: translate));
    if (fails case final error?) throw error;
    return answer ?? const InferenceResult(english: '', translated: '', wavePath: null);
  }
}
