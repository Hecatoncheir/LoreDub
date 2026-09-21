// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lore_dub/src/data/repositories/settings_repository.dart';
import 'package:lore_dub/src/data/repositories/session_repository.dart';
import 'package:lore_dub/src/data/repositories/model_repository.dart';
import 'package:lore_dub/src/data/repositories/runtime_repository.dart';
import 'package:lore_dub/src/data/repositories/update_repository.dart';
import 'package:lore_dub/src/data/services/model_catalog.dart';
import 'package:lore_dub/src/data/services/model_storage_service.dart';
import 'package:lore_dub/src/data/services/native_engine_service.dart';
import 'package:lore_dub/src/data/services/notification_service.dart';
import 'package:lore_dub/src/data/services/runtime_storage_service.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/data/services/update_service.dart';
import 'package:lore_dub/src/domain/session_coordinator.dart';
import 'package:lore_dub/src/domain/engine_event.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/built_voice.dart';
import 'package:lore_dub/src/domain/character.dart';
import 'package:lore_dub/src/domain/failure.dart';
import 'package:lore_dub/src/domain/game_process.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/voice_capture_bloc.dart';

import '../../../support/staged_dashboard.dart';

import 'package:lore_dub/src/ui/dashboard/cubits/session_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:lore_dub/src/data/repositories/cast_repository.dart';
import 'package:lore_dub/src/domain/session_config.dart';

import '../../../support/memory_cast.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CastRepository repository;
  late StagedDashboard cubits;
  late VoiceCaptureBloc voices;
  late SessionCoordinator sessions;

  setUp(() {
    repository = _CastRepository();
    cubits = StagedDashboard(
      repository,
      SettingsRepository(SettingsService()),
      ModelRepository(ModelStorageService()),
      RuntimeRepository(RuntimeStorageService()),
      UpdateRepository(
        UpdateService(
          client: MockClient((_) async => http.Response('offline', 503)),
          // Read from the platform otherwise, which a unit test does not have.
          packageInfo: Future.value(
            PackageInfo(
              appName: 'LoreDub',
              packageName: 'lore_dub',
              version: '0.15.0',
              buildNumber: '20',
            ),
          ),
        ),
        NotificationService(plugin: FlutterLocalNotificationsPlugin()),
      ),
      cast: CastRepository(NativeEngineService(), repository.cards),
    );
    // Every package in place: a sample needs the speech model, and a
    // recording needs the converter.
    cubits.stageInstalled(
      models: [
        for (final model in modelCatalog) ModelInstallState(model: model, installed: true),
      ],
    );
    sessions = SessionCoordinator();
    voices = VoiceCaptureBloc(
      repository,
      // The real one goes looking for the application directory, which a
      // unit test does not have.
      _FixedModelRepository(),
      cubits.settingsRepository,
      cubits.installed,
      cubits.failures,
      sessions,
      cubits.cast,
    );
  });

  tearDown(() async {
    await voices.close();
    await cubits.dispose();
  });

  const guard = Character(id: 'a1', name: 'Стражник', vector: [0.2, 0.4]);

  /// [cards] as the cast holds them, and the capture standing as [capture]
  /// -- what `blocTest`'s `seed` does, for a scenario of several steps.
  void stage(List<Character> cards, {VoiceCaptureState capture = const VoiceCaptureState()}) {
    cubits.cast.seed(CharacterLibrary(characters: cards));
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    voices.emit(capture);
  }

  /// [event] handed to the bloc and answered.
  Future<void> answered(VoiceCaptureEvent event) async {
    voices.add(event);
    await pumpEventQueue();
  }

  /// What the engine said, as it reaches the bloc.
  Future<void> said(EngineEvent event) async {
    repository.push(event);
    await pumpEventQueue();
  }

  test('leaves a session the dubbing screens hold off this screen', () async {
    stage(const []);

    // One engine serves both screens; a live session is not this screen's to
    // show, and its record buttons open on nothing but a session of its own.
    await said(
      const SessionStateChanged(
        status: PipelineStatus.listening,
        session: PipelineSession.live,
      ),
    );

    expect(voices.state.running, isFalse);

    await said(
      const SessionStateChanged(
        status: PipelineStatus.listening,
        session: PipelineSession.characters,
      ),
    );

    expect(voices.state.running, isTrue);

    // The engine coming to rest names no session: it ends this one as well.
    await said(const SessionStateChanged(status: PipelineStatus.idle));

    expect(voices.state.running, isFalse);
  });

  test('says nothing of a session the player stopped while it was starting', () async {
    stage(const []);

    voices.add(const RecordingSessionToggled(initializing: false, process: null));
    await Future<void>.delayed(Duration.zero);
    expect(voices.state.status, PipelineStatus.starting);

    // The button that starts the session is the one that stops it, and a
    // start that is stopped fails — for being stopped, which is no news.
    voices.add(const RecordingSessionToggled(initializing: false, process: null));
    await pumpEventQueue();
    await Future<void>.delayed(Duration.zero);

    expect(repository.stops, 1);
    expect(voices.state.status, PipelineStatus.idle);
    expect(cubits.failures.state, isNull);
  });

  group('a card built from files', () {
    setUp(() {
      stage([guard]);
      repository.building = const BuiltVoice(
        vector: [0.1, 0.2],
        gender: 'male',
        seconds: 12.5,
        used: 3,
        skipped: ['C:/music.mp3'],
        agreement: 0.91,
        weakest: 0.84,
        anchor: 'C:/work/dropped_1.wav',
      );
    });

    test('measures every recording at once and keeps what came of it', () async {
      await answered(
        VoiceFilesDropped('a1', const [
          'C:/one.ogg',
          'C:/two.ogg',
          'C:/three.ogg',
          'C:/music.mp3',
        ]),
      );

      expect(repository.builtFrom.single.length, 4, reason: 'all of them, in one go');
      expect(repository.stored.characters.single.vector, [0.1, 0.2]);
      expect(repository.stored.characters.single.gender, 'male');
      expect(repository.stored.characters.single.seconds, 12.5);
      // The clip the fingerprint stands closest to is what the card plays.
      expect(repository.kept['a1'], 'C:/work/dropped_1.wav');
      expect(voices.state.clips, contains('a1'));
      expect(voices.state.built?.used, 3);
      expect(voices.state.built?.skipped, ['C:/music.mp3']);
      expect(voices.state.builtId, 'a1');
      expect(voices.state.building, isFalse);
    });

    test('borrows a session of its own and puts it down again', () async {
      await answered(VoiceFilesDropped('a1', const ['C:/one.ogg']));

      expect(repository.fileSessionStarts, 1, reason: 'no game to listen to, only the converter');
      expect(repository.stops, 1, reason: 'and it is not left running');
    });

    test('leaves alone the dubbing that took the worker while the files were measured', () async {
      // A folder of recordings takes a while, and Live starting meanwhile
      // takes the worker over without a word to this screen. What the engine
      // holds when the measuring ends is the dubbing, which putting the
      // borrowed session down used to stop.
      repository.measuring = Completer<BuiltVoice>();
      voices.add(VoiceFilesDropped('a1', const ['C:/one.ogg']));
      await pumpEventQueue();
      expect(repository.builtFrom, hasLength(1), reason: 'the files are being measured');

      repository.takeOver();
      // The worker went with the session, so the measuring ends as stopped.
      repository.measuring!.completeError(const LoreDubFailure(FailureCode.pipelineStopped));
      await pumpEventQueue();

      expect(repository.stops, 0, reason: 'the session the engine holds is not the borrowed one');
      expect(cubits.failures.state, isNull, reason: 'a worker taken over is no failure');
      expect(voices.state.building, isFalse);
    });

    test('puts nothing down when the session it meant to borrow never came up', () async {
      // Live starting in the seconds the converter takes to load replaces
      // that start, which ends as stopped with nothing of its own left in
      // the engine — so a stop here landed on the start that replaced it.
      repository.fileSessionFailure = const LoreDubFailure(FailureCode.pipelineStopped);

      await answered(VoiceFilesDropped('a1', const ['C:/one.ogg']));

      expect(repository.stops, 0);
      expect(repository.builtFrom, isEmpty);
      expect(cubits.failures.state, isNull);
      expect(voices.state.building, isFalse);
    });

    test('measures through the session the screen is already recording with', () async {
      stage([guard], capture: VoiceCaptureState(status: PipelineStatus.listening));

      await answered(VoiceFilesDropped('a1', const ['C:/one.ogg']));

      expect(repository.fileSessionStarts, 0);
      expect(repository.stops, 0, reason: "the player's own session is theirs to end");
    });

    test('leaves the card alone while another is being recorded', () async {
      stage([
        guard,
      ], capture: VoiceCaptureState(status: PipelineStatus.listening, recordingId: 'a1'));

      await answered(VoiceFilesDropped('a1', const ['C:/one.ogg']));

      expect(repository.builtFrom, isEmpty);
    });

    test('keeps the fingerprint even when the clip cannot be kept', () async {
      repository.building = const BuiltVoice(vector: [0.3], used: 1, seconds: 2);

      await answered(VoiceFilesDropped('a1', const ['C:/one.ogg']));

      expect(repository.stored.characters.single.vector, [0.3]);
      expect(voices.state.clips, isNot(contains('a1')), reason: 'no anchor, no play button');
    });
  });

  test('keeps the whole take a recording heard', () async {
    stage([guard], capture: VoiceCaptureState(status: PipelineStatus.listening));

    await answered(const RecordingStarted('a1'));
    expect(repository.recordings, [true]);

    // The take is one recording, closed by the stop below: however long the
    // character went on, and whatever pauses they left, this is what the
    // card is measured from.
    await said(
      const CharacterVoiceMeasured(vector: [0.7, 0.1], gender: 'male', seconds: 24.5),
    );

    await answered(const RecordingStopped());

    expect(repository.recordings, [true, false]);
    final kept = cubits.cast.cast.single;
    expect(kept.vector, [0.7, 0.1]);
    expect(kept.gender, 'male');
    expect(kept.seconds, 24.5, reason: 'the take, not the longest line in it');
    expect(voices.state.heardSeconds, 0, reason: 'the clock is put away with the take');
  });

  test('leaves the card alone when a take held too little speech', () async {
    stage([guard], capture: VoiceCaptureState(status: PipelineStatus.listening));

    await answered(const RecordingStarted('a1'));
    await said(const CharacterVoiceMeasured(vector: [9], seconds: 0.8));

    await answered(const RecordingStopped());

    expect(cubits.cast.cast.single.vector, guard.vector);
  });

  test('keeps the clip the card was recorded from, and plays it back', () async {
    stage([guard], capture: VoiceCaptureState(status: PipelineStatus.listening));

    await answered(const RecordingStarted('a1'));
    await said(
      const CharacterVoiceMeasured(
        vector: [0.7, 0.1],
        seconds: 2.4,
        clip: r'C:\work\capture\segment-2.wav',
      ),
    );
    await answered(const RecordingStopped());

    expect(repository.kept['a1'], r'C:\work\capture\segment-2.wav');
    expect(voices.state.canPlay('a1'), isTrue);

    await answered(const ClipPlayed('a1'));

    expect(repository.played, [r'C:\work\capture\segment-2.wav']);
    expect(voices.state.playingId, isNull, reason: 'it has finished sounding');
  });

  test('offers nothing to play for a card that came from a file', () async {
    stage([guard]);

    expect(voices.state.canPlay('a1'), isFalse);

    await answered(const ClipPlayed('a1'));

    expect(repository.played, isEmpty);
  });

  test('speaks a sample in the voice the dubbing would read the card in', () async {
    stage([guard]);

    await answered(const SampleAsked('a1'));

    expect(repository.previewStarts, 1, reason: 'the speech model is loaded once');
    expect(repository.spoken.single, contains('Стражник'));
    expect(voices.state.previewReady, isTrue);
    expect(voices.state.previewingId, isNull);

    await answered(const SampleAsked('a1'));

    expect(repository.previewStarts, 1, reason: 'the one after it waits for nothing');
    expect(repository.spoken.length, 2);
  });

  test('leaves the sample alone while the game is being listened to', () async {
    stage([guard], capture: VoiceCaptureState(status: PipelineStatus.listening));

    await answered(const SampleAsked('a1'));

    expect(repository.spoken, isEmpty, reason: 'that worker has no speech model in it');
  });

  test('leaves the sample alone while files are being measured', () async {
    stage([guard], capture: VoiceCaptureState(buildingId: 'a1'));

    await answered(const SampleAsked('a1'));

    expect(repository.previewStarts, 0, reason: 'it would replace the worker measuring them');
    expect(repository.spoken, isEmpty);
  });

  test('loads the speech model again once the engine has come to rest', () async {
    stage([guard]);
    await answered(const SampleAsked('a1'));
    expect(voices.state.previewReady, isTrue);

    // A card measured from files puts its borrowed session down, or the
    // worker dies under the session it served: either way the engine stops,
    // and the speech model a sample was loaded into goes with it.
    await said(const SessionStateChanged(status: PipelineStatus.idle));

    expect(voices.state.previewReady, isFalse);

    await answered(const SampleAsked('a1'));

    expect(repository.previewStarts, 2, reason: 'skipped, the sample was told there is no worker');
    expect(repository.spoken, hasLength(2));
  });

  test('tells the session a sample was loaded for from the one that replaced it', () async {
    stage([guard], capture: VoiceCaptureState(previewReady: true));

    // Loading for a sample announces itself as well, and must not undo itself.
    await said(
      const SessionStateChanged(
        status: PipelineStatus.listening,
        session: PipelineSession.preview,
      ),
    );

    expect(voices.state.previewReady, isTrue);

    // A recording brings up a worker of its own, with no voice in it.
    await said(
      const SessionStateChanged(
        status: PipelineStatus.listening,
        session: PipelineSession.characters,
      ),
    );

    expect(voices.state.previewReady, isFalse);
  });

  group('while a dubbing session holds the worker', () {
    setUp(() {
      stage([guard]);
      sessions.reportPipeline(
        status: PipelineStatus.listening,
        session: PipelineSession.live,
        backends: const {},
      );
    });

    test('speaks no sample, which would take the worker from under it', () async {
      await answered(const SampleAsked('a1'));

      expect(repository.previewStarts, 0);
      expect(repository.spoken, isEmpty);
      expect(voices.state.previewingId, isNull);
    });

    test('measures no files', () async {
      await answered(VoiceFilesDropped('a1', const ['C:/one.ogg']));

      expect(repository.fileSessionStarts, 0);
      expect(repository.builtFrom, isEmpty);
      expect(voices.state.building, isFalse);
    });

    test('starts no recording', () async {
      voices.add(const RecordingSessionToggled(initializing: false, process: null));
      await pumpEventQueue();

      expect(repository.sessionStarts, 0);
      expect(voices.state.status, PipelineStatus.idle);
    });
  });

  test('is told by the pipeline whether a dubbing session holds the worker', () {
    // Neither cubit knows the other; each registers its half with the
    // coordinator, and this is what the cast screen reads there.
    final bagged = cubits.sessions;
    expect(bagged.dubbingRuns, isFalse);

    cubits.stageSession(const SessionState(status: PipelineStatus.listening));
    expect(bagged.dubbingRuns, isTrue);

    // A session resting under a pause keeps its worker and its models.
    cubits.stageSession(const SessionState(status: PipelineStatus.paused));
    expect(bagged.dubbingRuns, isTrue);
  });

  test('lets the dubbing screens end the session it holds', () async {
    stage(const [], capture: VoiceCaptureState(status: PipelineStatus.listening));

    await sessions.makeRoomForDubbing();

    expect(repository.stops, 1, reason: 'the cast screen registered how its session ends');
  });

  test('leaves the card alone when the recording heard nothing usable', () async {
    stage([guard], capture: VoiceCaptureState(status: PipelineStatus.listening));

    await answered(const RecordingStarted('a1'));
    await said(const CharacterVoiceMeasured(vector: [9], seconds: 0.5));
    await answered(const RecordingStopped());

    expect(cubits.cast.cast.single.vector, [0.2, 0.4], reason: 'as it was');
    expect(voices.state.recording, isFalse);
  });
}

/// The characters on disk, without a disk.
class _FixedModelRepository extends ModelRepository {
  _FixedModelRepository() : super(ModelStorageService());

  @override
  Future<String> directoryFor(ModelPackage model) async => 'models';
}

class _CastRepository extends SessionRepository {
  _CastRepository() : super(NativeEngineService());

  /// The cast's own files, which the cast repository reads rather than
  /// this one; kept here so a test reaches them where it reaches the rest.
  final cards = MemoryCharacters();
  CharacterLibrary get stored => cards.stored;
  set stored(CharacterLibrary value) => cards.stored = value;
  CharacterLibrary get incoming => cards.incoming;
  set incoming(CharacterLibrary value) => cards.incoming = value;
  Map<String, String> get kept => cards.kept;
  final recordings = <bool>[];

  /// What a card built from files answers with, and what it was asked for.
  BuiltVoice building = const BuiltVoice();
  final builtFrom = <List<String>>[];
  int fileSessionStarts = 0;
  int sessionStarts = 0;
  int stops = 0;

  /// Set to have the files take as long as the test says, the way decoding
  /// and embedding a folder of them does.
  Completer<BuiltVoice>? measuring;

  /// What the session borrowed for the files fails to start with, if it is to.
  Object? fileSessionFailure;

  /// The session the engine holds, numbered as the real repository numbers
  /// them: one more with every start and with every stop.
  int _session = 0;

  /// Another screen starting a session of its own, which takes the worker
  /// over without a word to this one.
  void takeOver() => _session++;

  /// What was played.
  final played = <String>[];
  final spoken = <String>[];
  int previewStarts = 0;

  @override
  Future<void> playWave(String wavePath) async => played.add(wavePath);

  @override
  Future<int> startVoiceFiles(WorkerPlan worker) async {
    fileSessionStarts++;
    final session = ++_session;
    if (fileSessionFailure case final failure?) throw failure;
    return session;
  }

  @override
  Future<BuiltVoice> buildVoice(List<String> paths) {
    builtFrom.add(paths);
    return measuring?.future ?? Future.value(building);
  }

  @override
  Future<void> startVoicePreview(WorkerPlan worker) async {
    previewStarts++;
    _session++;
  }

  @override
  Future<void> previewVoice({
    required String text,
    required String voice,
    List<double> timbre = const [],
  }) async => spoken.add(text);

  @override
  Future<void> recordCharacterVoice({required bool recording}) async => recordings.add(recording);

  /// The recording session on its way up, which a stop fails the way the
  /// real one fails a start it lands in.
  Completer<void>? _starting;

  @override
  Future<void> startCharacterVoices({
    required GameProcess? process,
    required AppSettings settings,
    required WorkerPlan worker,
  }) {
    sessionStarts++;
    _session++;
    return (_starting = Completer<void>()).future;
  }

  @override
  Future<void> stop() async {
    stops++;
    _session++;
    _starting?.completeError(const LoreDubFailure(FailureCode.pipelineStopped));
    _starting = null;
  }

  /// The real rule, which the repository's own test holds it to: only the
  /// session still held is ended.
  @override
  Future<void> stopSession(int session) async {
    if (session == _session) await stop();
  }

  final _said = StreamController<EngineEvent>.broadcast();

  void push(EngineEvent event) => _said.add(event);

  @override
  Stream<EngineEvent> get events => _said.stream;

  @override
  void dispose() {}
}
