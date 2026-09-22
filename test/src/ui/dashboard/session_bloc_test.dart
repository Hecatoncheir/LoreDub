// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lore_dub/src/domain/engine_event.dart';
import 'package:lore_dub/src/domain/screen_reading.dart';
import 'package:lore_dub/src/data/repositories/settings_repository.dart';
import 'package:lore_dub/src/data/repositories/session_repository.dart';
import 'package:lore_dub/src/data/repositories/runtime_repository.dart';
import 'package:lore_dub/src/data/repositories/update_repository.dart';
import 'package:lore_dub/src/data/services/model_catalog.dart';
import 'package:lore_dub/src/data/services/notification_service.dart';
import 'package:lore_dub/src/data/services/runtime_storage_service.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/data/services/update_service.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/compute_device.dart';
import 'package:lore_dub/src/domain/failure.dart';
import 'package:lore_dub/src/domain/game_process.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/ocr_region.dart';
import 'package:lore_dub/src/domain/model_selection.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart';

import '../../../support/staged_dashboard.dart';

import 'package:lore_dub/src/ui/dashboard/cubits/session_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/transcript_bloc.dart';
import 'package:lore_dub/src/data/repositories/voice_bank_repository.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/voice_capture_bloc.dart';
import 'package:lore_dub/src/domain/session_config.dart';

import '../../../support/fakes/fake_model_repository.dart';

/// A dubbed line as the engine reports it, with only the parts a test
/// cares about spelled out.
LineDubbed dubbed(
  String original, {
  String english = '',
  String translated = '',
  int latencyMs = 0,
  String? speaker,
  String? wave,
  bool snapshot = false,
}) => LineDubbed(
  line: TranscriptEntry(
    original: original,
    english: english,
    translated: translated,
    latency: Duration(milliseconds: latencyMs),
    speaker: speaker,
    spoken: wave,
  ),
  snapshot: snapshot,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SlowStartRepository repository;
  late StagedDashboard cubits;
  late DateTime now;
  late SessionBloc pipeline;

  /// Lets every pending microtask run, which is as far as a start that never
  /// finishes can get.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  /// The session standing as [value] -- what `blocTest`'s `seed` does.
  void stage(SessionState value) =>
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      pipeline.emit(value);

  setUp(() {
    // A frame drawn over the game is written through the settings, which
    // reach the disk; without this the write lands on a missing plugin.
    SharedPreferences.setMockInitialValues(const {});
    repository = _SlowStartRepository();
    cubits = StagedDashboard(
      repository,
      SettingsRepository(SettingsService()),
      FakeModelRepository(),
      RuntimeRepository(RuntimeStorageService()),
      UpdateRepository(
        UpdateService(
          client: MockClient((_) async => http.Response('offline', 503)),
          // Read from the platform otherwise, which a unit test does not have.
          packageInfo: Future.value(
            PackageInfo(
              appName: 'LoreDub',
              packageName: 'lore_dub',
              version: '0.4.0',
              buildNumber: '5',
            ),
          ),
        ),
        NotificationService(plugin: FlutterLocalNotificationsPlugin()),
      ),
      voiceBank: _Banks(),
    );
    // The whole default output needs no process, and every package is in
    // place, so a press is all a start takes.
    cubits.settingsRepository.seed(
      const AppSettings(audioCaptureSource: AudioCaptureSource.system),
    );
    cubits.stageInstalled(
      models: [
        for (final model in modelCatalog) ModelInstallState(model: model, installed: true),
      ],
    );
    now = DateTime(2026, 9, 11, 12);
    pipeline = SessionBloc(
      repository,
      FakeModelRepository(),
      cubits.settingsRepository,
      cubits.installed,
      cubits.sourcesRepository,
      cubits.failures,
      cubits.sessions,
      _Banks(),
      clock: () => now,
    );
  });

  tearDown(() async {
    await pipeline.close();
    await cubits.dispose();
  });

  test('leaves a session another screen holds off this screen', () async {
    pipeline.listen();

    // One engine serves both screens, and this is what the characters screen
    // starting its recording session announces. It is not this screen's.
    repository.push(
      const SessionStateChanged(
        status: PipelineStatus.listening,
        session: PipelineSession.characters,
      ),
    );
    await settle();

    expect(pipeline.state.status, PipelineStatus.idle);
    expect(pipeline.state.liveRunning, isFalse);

    // Its own session still arrives.
    repository.push(
      const SessionStateChanged(
        status: PipelineStatus.listening,
        session: PipelineSession.live,
      ),
    );
    await settle();

    expect(pipeline.state.liveRunning, isTrue);

    // The engine coming to rest names no session: it ends every screen's.
    repository.push(const SessionStateChanged(status: PipelineStatus.idle));
    await settle();

    expect(pipeline.state.status, PipelineStatus.idle);
  });

  test('takes the worker over from the characters screen', () async {
    // The recording session holds the worker with no whisper in it, so live
    // dubbing cannot share it: it starts afresh, as it does over a snapshot.
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    cubits.voices.emit(const VoiceCaptureState(status: PipelineStatus.listening));

    cubits.pipeline.add(const LiveToggled(initializing: false));
    await settle();

    expect(cubits.voices.state.running, isFalse, reason: 'the recording gave way');
    expect(repository.stops, 1);
    expect(repository.starts, 1);
    expect(cubits.pipeline.state.session, PipelineSession.live);
  });

  test('takes a second press straight after Start for the rest of a double-click', () async {
    pipeline.add(const LiveToggled(initializing: false));
    await settle();
    expect(pipeline.state.status, PipelineStatus.starting);
    expect(repository.starts, 1);

    now = now.add(const Duration(milliseconds: 300));
    pipeline.add(const LiveToggled(initializing: false));
    await pumpEventQueue();

    expect(pipeline.state.status, PipelineStatus.starting, reason: 'the start goes on');
    expect(repository.stops, 0);
  });

  test('still cancels a start when asked once the double-click is over', () async {
    pipeline.add(const LiveToggled(initializing: false));
    await settle();

    now = now.add(SessionBloc.doubleClickGrace);
    pipeline.add(const LiveToggled(initializing: false));
    await pumpEventQueue();

    expect(pipeline.state.status, PipelineStatus.idle);
    expect(repository.stops, 1);
  });

  test('says nothing of a start the player cancelled', () async {
    final statuses = <PipelineStatus>[];
    final watching = pipeline.stream.listen((state) => statuses.add(state.status));
    addTearDown(watching.cancel);
    pipeline.add(const LiveToggled(initializing: false));
    await settle();

    now = now.add(SessionBloc.doubleClickGrace);
    pipeline.add(const LiveToggled(initializing: false));
    await pumpEventQueue();
    await settle();

    // The start ends as stopped, which is what was asked of it: an error
    // here stood on the screen until the worker had died, and left a banner
    // about a stop under a session that was only ever cancelled.
    expect(statuses, isNot(contains(PipelineStatus.error)));
    expect(pipeline.state.status, PipelineStatus.idle);
    expect(cubits.failures.state, isNull);
  });

  test('comes to rest when another screen takes the worker from a start', () async {
    pipeline.add(const LiveToggled(initializing: false));
    await settle();
    expect(pipeline.state.status, PipelineStatus.starting);

    // A sample asked for on the characters screen starts a worker of its
    // own over this one. Nothing is stopped here, so nothing else would
    // ever move this screen on from a start that is no longer running.
    repository.failStart(const LoreDubFailure(FailureCode.pipelineStopped));
    await settle();

    expect(pipeline.state.status, PipelineStatus.idle);
    expect(cubits.failures.state, isNull);
    expect(repository.stops, 0);
  });

  test('still says why a start failed on its own', () async {
    pipeline.add(const LiveToggled(initializing: false));
    await settle();

    repository.failStart(const LoreDubFailure(FailureCode.workerStartTimeout));
    await settle();

    expect(pipeline.state.status, PipelineStatus.error);
    expect(
      cubits.failures.state,
      isA<LoreDubFailure>().having((f) => f.code, 'code', FailureCode.workerStartTimeout),
    );
  });

  test('pauses and resumes on the hotkeys pressed in the game', () async {
    pipeline.listen();
    stage(const SessionState(status: PipelineStatus.listening));

    repository.push(const HotkeyPressed(HotkeyAction.pause));
    await settle();
    expect(pipeline.state.status, PipelineStatus.paused);
    expect(pipeline.state.running, isTrue, reason: 'a paused session is still a session');

    repository.push(const HotkeyPressed(HotkeyAction.pause));
    await settle();
    expect(pipeline.state.status, PipelineStatus.paused, reason: 'pausing twice changes nothing');

    repository.push(const HotkeyPressed(HotkeyAction.resume));
    await settle();
    expect(pipeline.state.status, PipelineStatus.listening);
    expect(repository.stops, 0, reason: 'neither tears the session down');
    expect(repository.pausesTold, [true, false], reason: 'the capture is told, once each way');
  });

  test('stops for good from a pause', () async {
    stage(const SessionState(status: PipelineStatus.paused));

    pipeline.add(const SessionStopped());
    await pumpEventQueue();

    expect(pipeline.state.status, PipelineStatus.idle);
    expect(repository.stops, 1);
  });

  test('forgets what the session found out once it stops', () async {
    // The detected language, the voice last read in and the devices it
    // settled on belonged to that session; the next one finds them anew.
    stage(
      const SessionState(
        status: PipelineStatus.listening,
        detectedLanguage: 'ja',
        spokenVoice: 'kseniya',
        activeBackends: {ComputeStage.recognition: ComputeBackend.cuda},
      ),
    );

    pipeline.add(const LiveToggled(initializing: false));
    await pumpEventQueue();

    expect(pipeline.state.status, PipelineStatus.idle);
    expect(pipeline.state.detectedLanguage, isNull);
    expect(pipeline.state.spokenVoice, isNull);
    expect(pipeline.state.activeBackends, isEmpty);
  });

  group('a line already read', () {
    test('keeps what it was read as, and is read again on request', () async {
      pipeline.listen();
      stage(const SessionState(status: PipelineStatus.listening));

      repository.push(
        dubbed(
          'Fire in the hole!',
          english: 'Fire in the hole!',
          translated: 'Ложись!',
          latencyMs: 900,
          wave: 'work/speech-7.wav',
        ),
      );
      await settle();

      final line = cubits.transcript.state.transcript.single;
      expect(line.spoken, 'work/speech-7.wav');
      cubits.transcript.add(LineSpokenAgain(line));
      await settle();
      expect(repository.playedAgain, ['work/speech-7.wav']);
    });

    test('a line that was never voiced has nothing to play', () async {
      cubits.transcript.add(
        const LineSpokenAgain(
          TranscriptEntry(original: 'x', english: 'x', translated: 'x', latency: Duration.zero),
        ),
      );
      await settle();

      expect(repository.playedAgain, isEmpty);
    });
  });

  group('the voice picked while a session runs', () {
    test('reaches the worker rather than waiting for the next start', () async {
      stage(
        const SessionState(
          status: PipelineStatus.listening,
          session: PipelineSession.screen,
        ),
      );

      await cubits.settingsRepository.save(const AppSettings(voice: 'male_0'));

      expect(repository.voicesTold, ['male_0']);
    });

    test('is not sent twice, and not at all while nothing runs', () async {
      await cubits.settingsRepository.save(const AppSettings(voice: 'male_1'));
      expect(repository.voicesTold, isEmpty, reason: 'the next start will carry it');

      stage(
        const SessionState(
          status: PipelineStatus.listening,
          session: PipelineSession.live,
        ),
      );
      await cubits.settingsRepository.save(const AppSettings(voice: 'male_1'));
      await cubits.settingsRepository.save(const AppSettings(voice: 'male_1'));

      expect(repository.voicesTold, ['male_1']);
    });
  });

  group('the frame drawn over the game', () {
    test('follows the switch, the game and the region', () async {
      const game = GameProcess(pid: 4242, name: 'game.exe', path: 'game.exe');
      cubits.sourcesRepository.select(game);
      // The pipeline puts the overlay in step whenever the settings reach
      // it, which now includes the value it gets on subscribing, so what
      // matters is that none of those asked for a frame.
      expect(
        repository.framesDrawn,
        everyElement(isNull),
        reason: 'nothing was asked for yet',
      );

      await cubits.settingsRepository.save(
        const AppSettings(showFrameOverlay: true, ocrRegion: OcrRegion(top: 0.8)),
      );

      expect(repository.framesDrawn.last?.processId, 4242);
      expect(repository.framesDrawn.last?.region.top, 0.8);
      expect(
        repository.idleKeys.last,
        Hotkey.defaultFrameOverlay,
        reason: 'the key that hides it answers while nothing runs',
      );
    });

    test('is drawn over the whole screen where that is what is read', () async {
      await cubits.settingsRepository.save(
        const AppSettings(showFrameOverlay: true, screenSource: ScreenSource.wholeScreen),
      );

      expect(repository.framesDrawn.last?.processId, 0, reason: 'no window to measure against');
    });

    test('is taken off with the switch, and its key with it', () async {
      const game = GameProcess(pid: 7, name: 'game.exe', path: 'game.exe');
      cubits.sourcesRepository.select(game);
      await cubits.settingsRepository.save(const AppSettings(showFrameOverlay: true));

      await cubits.settingsRepository.save(const AppSettings());

      expect(repository.framesDrawn.last, isNull);
      expect(repository.idleKeys.last, isNull);
    });

    test('its key shows it and takes it off again', () async {
      pipeline.listen();
      cubits.sourcesRepository.select(
        const GameProcess(pid: 9, name: 'game.exe', path: 'game.exe'),
      );

      repository.push(const HotkeyPressed(HotkeyAction.frameOverlay));
      await settle();
      expect(cubits.settings.settings.showFrameOverlay, isTrue);

      repository.push(const HotkeyPressed(HotkeyAction.frameOverlay));
      await settle();
      expect(cubits.settings.settings.showFrameOverlay, isFalse);
      expect(repository.framesDrawn.last, isNull);
    });
  });

  group('the screen session', () {
    const waiting = SessionState(
      status: PipelineStatus.listening,
      session: PipelineSession.screen,
    );

    test('loads only the translator and the voice', () async {
      // The frame is read out of one window, so the game is named first.
      cubits.sourcesRepository.select(
        const GameProcess(pid: 4242, name: 'game.exe', path: 'game.exe'),
      );
      pipeline.add(const ScreenToggled(initializing: false));
      await pumpEventQueue();

      expect(repository.snapshotStarts, 1);
      expect(repository.snapshotModels.translation, isNotNull);
      expect(repository.snapshotModels.speech, isNotNull);
      expect(repository.snapshotModels.whisper, isNull, reason: 'nothing is heard');
      expect(repository.snapshotModels.converter, isNull);
      expect(pipeline.state.session, PipelineSession.screen);
      expect(repository.starts, 0, reason: 'nothing is captured');
    });

    test('keeps the last ten subtitles, the newest on top', () async {
      pipeline.listen();
      stage(waiting);

      for (var line = 1; line <= 12; line++) {
        repository.push(
          dubbed('line $line', english: 'line $line', translated: 'строка $line', latencyMs: 100),
        );
      }
      await settle();

      expect(cubits.transcript.state.transcript, hasLength(TranscriptState.subtitlesKept));
      expect(cubits.transcript.state.transcript.first.original, 'line 12');
      expect(
        cubits.transcript.state.transcript.last.original,
        'line 3',
        reason: 'the older two left as the newer arrived',
      );
    });

    test('follows the voices behind the subtitles when it is asked to', () async {
      const game = GameProcess(pid: 4242, name: 'game.exe', path: 'game.exe');
      cubits.sourcesRepository.select(game);
      await cubits.settingsRepository.save(const AppSettings(screenVoices: true));

      pipeline.add(const ScreenToggled(initializing: false, reading: ScreenReading.subtitles));
      await pumpEventQueue();

      expect(repository.screenHeardVoices, isTrue);
      expect(
        repository.snapshotModels.converter,
        isNotNull,
        reason: 'the converter is what hears who is speaking',
      );
    });

    test('reads a snippet without a game to take a window from', () async {
      // Nothing is scanned, so there is no window to read it out of: the
      // key picks out whatever is on the screen.
      pipeline.add(const ScreenToggled(initializing: false, reading: ScreenReading.snippets));
      await pumpEventQueue();

      expect(repository.screenReadings, [ScreenReading.snippets]);
      expect(pipeline.state.screenReading, ScreenReading.snippets);
    });

    test('changes what is read by starting that reading over the one running', () async {
      const game = GameProcess(pid: 4242, name: 'game.exe', path: 'game.exe');
      cubits.sourcesRepository.select(game);
      pipeline.add(const ScreenToggled(initializing: false, reading: ScreenReading.snippets));
      await pumpEventQueue();
      // The frame is read out of the game's window, so the session that
      // takes over is one that knows which game.
      stage(
        waiting.copyWith(screenReading: ScreenReading.snippets),
      );

      pipeline.add(const ScreenToggled(initializing: false, reading: ScreenReading.subtitles));
      await pumpEventQueue();

      expect(repository.stops, 1, reason: 'the session that was running ended');
      expect(repository.screenReadings, [ScreenReading.snippets, ScreenReading.subtitles]);
      expect(pipeline.state.screenReading, ScreenReading.subtitles);
    });

    test('its own button ends it rather than starting it again', () async {
      const game = GameProcess(pid: 4242, name: 'game.exe', path: 'game.exe');
      cubits.sourcesRepository.select(game);
      pipeline.add(const ScreenToggled(initializing: false));
      await pumpEventQueue();
      stage(waiting);

      pipeline.add(const ScreenToggled(initializing: false));
      await pumpEventQueue();

      expect(repository.stops, 1);
      expect(repository.snapshotStarts, 1);
      expect(pipeline.state.status, PipelineStatus.idle);
    });

    test('moves the subtitle frame to what was drawn over the game', () async {
      pipeline.listen();
      stage(waiting);

      repository.push(
        const SubtitleFrameMoved(OcrRegion(left: 0.1, top: 0.7, right: 0.9, bottom: 0.95)),
      );
      await settle();

      expect(
        cubits.settings.settings.ocrRegion,
        const OcrRegion(left: 0.1, top: 0.7, right: 0.9, bottom: 0.95),
        reason: 'the picker shows where the reading moved, and the next session starts there',
      );
      expect(pipeline.state.frameMissed, isFalse);
    });

    test('leaves the frame where it was when the selection missed the window', () async {
      pipeline.listen();
      stage(waiting);
      final before = cubits.settings.settings.ocrRegion;

      repository.push(const SubtitleFrameMoved(null));
      await settle();

      expect(cubits.settings.settings.ocrRegion, before);
      expect(pipeline.state.frameMissed, isTrue);
    });

    test('keeps a selection apart from the live transcript', () async {
      pipeline.listen();
      stage(waiting);

      repository
        ..push(const SnapshotReading())
        ..push(const SnapshotRead(text: 'Press E to open'));
      await settle();
      expect(
        cubits.transcript.state.snapshotReading,
        isTrue,
        reason: 'the translation is on its way',
      );

      repository.push(
        dubbed(
          'Press E to open',
          translated: 'Нажмите E, чтобы открыть',
          latencyMs: 800,
          snapshot: true,
        ),
      );
      await settle();
      expect(cubits.transcript.state.snapshots.single.translated, 'Нажмите E, чтобы открыть');
      expect(cubits.transcript.state.transcript, isEmpty);
      expect(cubits.transcript.state.snapshotReading, isFalse);
    });

    test('says when a selection held no text', () async {
      pipeline.listen();
      stage(waiting);

      repository
        ..push(const SnapshotReading())
        ..push(const SnapshotRead(text: ''));
      await settle();

      expect(cubits.transcript.state.snapshotMissed, isTrue);
      expect(cubits.transcript.state.snapshotReading, isFalse);
    });

    test('gives the worker over when live dubbing starts', () async {
      stage(waiting);

      pipeline.add(const LiveToggled(initializing: false));
      await settle();

      expect(repository.stops, 1, reason: 'the worker was loaded without whisper');
      expect(repository.starts, 1);
      expect(pipeline.state.session, PipelineSession.live);
    });

    test('leaves live dubbing to be stopped from its own screen', () async {
      stage(const SessionState(status: PipelineStatus.listening));

      pipeline.add(const ScreenToggled(initializing: false));
      await pumpEventQueue();

      expect(repository.stops, 0);
      expect(repository.snapshotStarts, 0);
    });
  });

  // An error carrying nothing to show used to be a case of its own: the
  // banner had to survive one. `EngineFailed` cannot be built without a
  // failure, so there is no longer such an event to survive.
  test('raises the banner for a capture failure', () async {
    pipeline.listen();
    const failure = LoreDubFailure(
      FailureCode.captureFailed,
      detail: 'English OCR language is not installed.',
    );

    repository.push(const EngineFailed(failure));
    await settle();

    expect(cubits.failures.state, same(failure));
  });

  test('collects the voices of the scene, newest line first', () async {
    pipeline.listen();

    repository.push(dubbed('Halt!', translated: 'Стоять!', speaker: 'timbre:0'));
    repository.push(dubbed('What do you want?', translated: 'Чего тебе?', speaker: 'character:a1'));
    repository.push(dubbed('Move along.', translated: 'Проходи.', speaker: 'timbre:0'));
    await settle();

    final speakers = cubits.transcript.state.speakers;
    expect(
      speakers.map((speaker) => speaker.key),
      ['timbre:0', 'character:a1'],
      reason: 'in the order they first spoke',
    );
    expect(speakers.first.lines, 2);
    expect(speakers.first.line, 'Проходи.', reason: 'the last thing they said');
  });

  test('leaves a line nobody was heard in out of the scene list', () async {
    pipeline.listen();

    repository.push(dubbed('Hello', translated: 'Привет'));
    await settle();

    expect(cubits.transcript.state.transcript, hasLength(1));
    expect(cubits.transcript.state.speakers, isEmpty);
  });

  group('placing the voices before the dubbing', () {
    test('listens through the converter alone, translating nothing', () async {
      pipeline.add(const SceneToggled(initializing: false));
      await settle();

      expect(repository.sceneStarts, 1);
      expect(pipeline.state.session, PipelineSession.scene);
      expect(pipeline.state.status, PipelineStatus.starting);
      expect(repository.starts, 0, reason: 'nothing is dubbed');
      expect(
        repository.sceneBank,
        'voice_bank/.json',
        reason: 'the bank the dubbing session will read',
      );
    });

    test('places a voice by what was heard, with no words to show', () async {
      pipeline.listen();
      stage(
        const SessionState(
          status: PipelineStatus.listening,
          session: PipelineSession.scene,
        ),
      );

      repository.push(const SceneVoiceHeard(speaker: 'timbre:0', seconds: 1.8));
      repository.push(const SceneVoiceHeard(speaker: 'timbre:0', seconds: 3.2));
      repository.push(const SceneVoiceHeard(speaker: 'character:a1', seconds: 2));
      await settle();

      final voices = cubits.transcript.state.speakers;
      expect(voices.map((voice) => voice.key), ['timbre:0', 'character:a1']);
      expect(voices.first.lines, 2);
      expect(voices.first.seconds, 3.2, reason: 'the longest phrase stands');
      expect(voices.first.line, isEmpty, reason: 'nothing was recognized');
    });

    test('gives the worker over when the dubbing starts', () async {
      stage(
        const SessionState(
          status: PipelineStatus.listening,
          session: PipelineSession.scene,
        ),
      );

      pipeline.add(const LiveToggled(initializing: false));
      await settle();

      expect(repository.stops, 1, reason: 'the listening session is ended first');
      expect(repository.starts, 1);
      expect(pipeline.state.session, PipelineSession.live);
    });

    test('needs the converter, so it waits while nothing can hear', () {
      cubits.stageInstalled(
        models: [
          for (final model in modelCatalog)
            ModelInstallState(
              model: model,
              installed: model.kind != ModelKind.voiceConversion,
            ),
        ],
      );

      expect(
        pipeline.state.canStartScene(
          ModelSelection(models: cubits.downloads.state.models, settings: const AppSettings()),
          initializing: false,
          process: null,
        ),
        isFalse,
      );
    });
  });
}

/// A start that never finishes, as a first start does while the worker loads
/// Marian and Silero — unless it is stopped, which fails it the way the real
/// one fails a start still on its way.
class _SlowStartRepository extends Fake implements SessionRepository {
  final _events = StreamController<EngineEvent>.broadcast();
  Completer<void>? _starting;
  int starts = 0;
  int stops = 0;
  int snapshotStarts = 0;

  /// What each screen session was asked to read, and whether the last of
  /// them was to follow the voices behind the subtitles.
  final screenReadings = <ScreenReading>[];
  bool screenHeardVoices = false;

  /// What was drawn over the game, in order: a pair for every frame shown
  /// and null for every one taken off.
  final framesDrawn = <({int processId, OcrRegion region})?>[];

  /// The keys registered while nothing runs.
  final idleKeys = <Hotkey?>[];

  /// The voices a running session was told to read in.
  final voicesTold = <String>[];

  /// The readings played again from the transcript.
  final playedAgain = <String>[];

  /// Whether the capture was told to drop what it hears, call by call.
  final pausesTold = <bool>[];

  @override
  Future<void> pause() async => pausesTold.add(true);

  @override
  Future<void> resume() async => pausesTold.add(false);

  @override
  Future<void> speakAgain(String wavePath) async => playedAgain.add(wavePath);

  @override
  Future<void> useVoice(String voice) async => voicesTold.add(voice);

  @override
  void showFrameOverlay({required int processId, required OcrRegion region}) =>
      framesDrawn.add((processId: processId, region: region));

  @override
  void hideFrameOverlay() => framesDrawn.add(null);

  @override
  void setIdleHotkeys(AppSettings settings) => idleKeys.add(
    settings.showFrameOverlay ? settings.frameOverlayHotkey : null,
  );
  ModelPaths snapshotModels = const ModelPaths();

  void push(EngineEvent event) => _events.add(event);

  /// Ends the start in progress with [failure], as the engine would.
  void failStart(Object failure) {
    _starting?.completeError(failure);
    _starting = null;
  }

  @override
  Stream<EngineEvent> get events => _events.stream;

  @override
  Future<void> start({
    required GameProcess? process,
    required AppSettings settings,
    required WorkerPlan worker,
    required bool translateSpeech,
  }) {
    starts++;
    return (_starting = Completer<void>()).future;
  }

  @override
  Future<void> startScreenText({
    required ScreenReading reading,
    required bool hearsVoices,
    required GameProcess? process,
    required AppSettings settings,
    required WorkerPlan worker,
  }) async {
    snapshotStarts++;
    screenHeardVoices = hearsVoices;
    snapshotModels = worker.models;
    screenReadings.add(reading);
  }

  int sceneStarts = 0;
  String? sceneBank;

  @override
  Future<void> startSceneVoices({
    required GameProcess? process,
    required AppSettings settings,
    required WorkerPlan worker,
  }) async {
    sceneStarts++;
    sceneBank = worker.voiceBank;
  }

  @override
  Future<void> stop() async {
    stops++;
    failStart(const LoreDubFailure(FailureCode.pipelineStopped));
  }

  @override
  void dispose() {
    unawaited(_events.close());
  }
}

/// The characters are remembered by default, so a start asks for the game's
/// bank; naming the file must not go looking for the application directory.
class _Banks extends VoiceBankRepository {
  @override
  Future<String> fileFor(String game) async => 'voice_bank/$game.json';
}
