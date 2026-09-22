// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// The dubbing page: the game picked, the start, the transcript and the scene.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/capture_sources.dart';
import 'package:lore_dub/src/domain/character.dart';
import 'package:lore_dub/src/domain/game_process.dart';
import 'package:lore_dub/src/domain/glossary.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart'
    show PipelineSession, PipelineStatus, SceneSpeaker, TranscriptEntry;
import 'package:lore_dub/src/ui/glossary/bloc/glossary_bloc.dart';
import 'package:lore_dub/src/ui/shell/bloc/navigation_cubit.dart';
import 'package:lore_dub/src/ui/common/bloc/session_bloc.dart';
import 'package:lore_dub/src/ui/common/bloc/transcript_bloc.dart';
import 'package:lore_dub/src/ui/characters/bloc/voice_capture_bloc.dart';
import 'package:lore_dub/src/ui/live/source_controls.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/dashboard_harness.dart';
import '../../../support/mock_blocs.dart';
import '../../../support/staged_dashboard.dart';

void main() {
  // What `captureAny` stands in with before anything is captured.
  setUpAll(registerEventFallbacks);

  testWidgets('keeps the process picker usable at every window width', (tester) async {
    // The wide row puts the picker between a fixed switch and a fixed
    // language block; too narrow a window used to squeeze it to a stub and
    // break its label across three lines mid-word.
    for (final width in [960.0, 1100.0, 1280.0, 1500.0, 1920.0]) {
      await pumpLoreDub(tester, Size(width, 800));

      final label = find.text('Процесс игры');
      expect(label, findsOneWidget, reason: 'at $width');
      expect(
        tester.getSize(find.byType(DropdownMenu<GameProcess>)).width,
        greaterThanOrEqualTo(320),
        reason: 'the picker is squeezed at $width',
      );
      // One line: a wrapped label is taller than a single row of text.
      expect(tester.getSize(label).height, lessThan(30), reason: 'wrapped at $width');
    }
  });

  testWidgets('opens the process list below the field so the typing stays in sight', (
    tester,
  ) async {
    final cubits = stage(buildCubits(), models: catalogue());
    cubits.sourcesRepository.seed(
      CaptureSources(
        processes: [
          for (var index = 0; index < 40; index++)
            GameProcess(pid: 1000 + index, name: 'game$index.exe', path: 'C:\\game$index.exe'),
        ],
      ),
    );
    // A short window: the forty entries are far taller than the room left.
    await pumpDashboard(tester, cubits, const Size(1280, 700));
    await tester.pumpAndSettle();

    final field = find.descendant(
      of: find.byType(DropdownMenu<GameProcess>),
      matching: find.byType(TextField),
    );
    await tester.tap(field);
    await tester.pumpAndSettle();

    final first = find.text('game0.exe  ·  PID 1000').hitTestable();
    expect(first, findsOneWidget);
    expect(
      tester.getTopLeft(first).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(field).dy),
      reason: 'the list must not slide up over what is being typed',
    );
    expect(
      tester.getBottomLeft(find.text('game0.exe  ·  PID 1000').hitTestable()).dy,
      lessThanOrEqualTo(700),
    );
  });

  testWidgets('aligns source actions with the process selector', (tester) async {
    await pumpLoreDub(tester, const Size(1280, 720));

    final selector = find.ancestor(
      of: find.text('Процесс игры'),
      matching: find.byType(InputDecorator),
    );
    final refresh = find.byTooltip('Обновить список процессов');

    expect(selector, findsOneWidget);
    expect(refresh, findsOneWidget);
    expect(
      (tester.getCenter(selector).dy - tester.getCenter(refresh).dy).abs(),
      lessThanOrEqualTo(1),
    );
  });

  testWidgets('filters processes and switches to the full system stream', (
    tester,
  ) async {
    await pumpLoreDub(tester, const Size(1280, 720));

    final pickerFinder = find.byType(DropdownMenu<GameProcess>);
    var picker = tester.widget<DropdownMenu<GameProcess>>(pickerFinder);
    expect(picker.enableFilter, isTrue);
    expect(picker.requestFocusOnTap, isTrue);
    expect(picker.enabled, isTrue);

    await tester.tap(find.text('Звук системы'));
    await tester.pumpAndSettle();

    picker = tester.widget<DropdownMenu<GameProcess>>(pickerFinder);
    expect(picker.enabled, isFalse);
    expect(
      find.text('Захватывается весь дефолтный поток, кроме звука LoreDub'),
      findsOneWidget,
    );
  });

  testWidgets('holds the game while a card is being recorded', (tester) async {
    final cubits = stage(buildCubits(), settings: const AppSettings(), models: catalogue());
    await pumpDashboard(tester, cubits, const Size(1280, 720));

    final picker = find.byType(DropdownMenu<GameProcess>);
    expect(tester.widget<DropdownMenu<GameProcess>>(picker).enabled, isTrue);

    // The characters screen records through the game it started with, and
    // this is the same choice under another window.
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    cubits.voices.emit(const VoiceCaptureState(status: PipelineStatus.listening));
    // Twice: a cubit hands its state to listeners a microtask later, and the
    // frame that draws it is the one after that.
    await tester.pump();
    await tester.pump();

    expect(
      tester.widget<DropdownMenu<GameProcess>>(picker).enabled,
      isFalse,
      reason: 'the recording listens to the game this would change',
    );
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Обновить список процессов'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
      reason: 'and a refresh beside it can drop the selection',
    );
  });

  testWidgets('never lets the game be silenced while its sound is what we hear', (tester) async {
    Future<Slider> volumeSlider(AppSettings settings) async {
      await pumpDashboard(
        tester,
        stage(buildCubits(), settings: settings, models: catalogue()),
        const Size(1280, 1000),
      );
      await tester.scrollUntilVisible(
        find.text('Оригинальный звук'),
        300,
        scrollable: liveScroller(),
      );
      await tester.pumpAndSettle();
      return tester.widget<Slider>(find.byKey(const ValueKey('originalVolume')));
    }

    // A zero left over from subtitle mode, now that the game's own sound is
    // what the pipeline listens to: Windows takes the capture after this
    // volume, so at zero nothing would ever be heard.
    final dubbing = await volumeSlider(const AppSettings(originalVolume: 0));
    expect(dubbing.min, AppSettings.audibleDuck);
    expect(dubbing.max, AppSettings.loudestDuck);
    expect(dubbing.value, AppSettings.audibleDuck, reason: 'the stored zero is lifted');
    expect(dubbing.divisions, 20);

    // The pace slider beside it reads the same bounds the node panel does.
    final pace = tester.widget<Slider>(find.byKey(const ValueKey('ttsSpeed')));
    expect(pace.min, AppSettings.slowestSpeech);
    expect(pace.max, AppSettings.fastestSpeech);
    expect(pace.divisions, AppSettings.speechDivisions);
  });

  testWidgets('names the audio path while dubbing what the game says', (tester) async {
    final cubits = stage(buildCubits(), settings: const AppSettings());
    await pumpDashboard(tester, cubits, const Size(1280, 720));

    expect(find.text('Захватывается только звук выбранного процесса'), findsOneWidget);
    expect(find.text('Whisper → English → Marian → Русский → Vosk'), findsOneWidget);
  });

  testWidgets('names the original language instead of detecting it', (tester) async {
    await pumpLoreDub(tester, const Size(1280, 720));

    final dropdown = find.byKey(const ValueKey('sourceLanguage'));
    expect(find.text('Определять язык'), findsOneWidget);
    expect(tester.widget<DropdownButtonFormField<String>>(dropdown).onChanged, isNull);

    await tester.tap(
      find.descendant(of: find.byType(SourceControls), matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<DropdownButtonFormField<String>>(dropdown);
    expect(field.onChanged, isNotNull);

    field.onChanged!('ja');
    await tester.pumpAndSettle();

    final saved = await SettingsService().load();
    expect(saved.detectSourceLanguage, isFalse);
    expect(saved.sourceLanguage, 'ja');
    expect(saved.effectiveSourceLanguage, 'ja');
  });

  testWidgets('shows how far the startup got and what it is loading', (tester) async {
    final cubits = stage(
      buildCubits(),
      status: PipelineStatus.starting,
      startupProgress: 0.35,
      startupStage: 'Загрузка Transformers',
    );
    await pumpDashboard(tester, cubits, const Size(1280, 720));

    expect(find.text('Запуск 35%'), findsOneWidget);
    expect(find.text('Загрузка Transformers'), findsOneWidget);
    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(indicator.value, 0.35);
  });

  testWidgets('drops the progress indicator once the pipeline listens', (tester) async {
    final cubits = stage(buildCubits(), status: PipelineStatus.listening);
    await pumpDashboard(tester, cubits, const Size(1280, 720));

    expect(find.text('Остановить'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('names the language auto-detection settled on', (tester) async {
    final cubits = stage(buildCubits(), detectedLanguage: 'ja');
    await pumpDashboard(tester, cubits, const Size(1280, 720));

    expect(find.text('Определён: Японский'), findsOneWidget);
    expect(find.text('Определять язык'), findsNothing, reason: 'the answer takes its place');
  });

  testWidgets('goes back to the plain toggle label once stopped', (tester) async {
    final cubits = stage(
      buildCubits(),
      status: PipelineStatus.listening,
      detectedLanguage: 'ja',
    );
    await pumpDashboard(tester, cubits, const Size(1280, 720));
    expect(find.text('Определён: Японский'), findsOneWidget);

    // What a stop leaves -- the detection is the session's and goes with
    // it (`session_bloc_test.dart`).
    cubits.stageSession(const SessionState());
    await tester.pumpAndSettle();

    expect(find.text('Определять язык'), findsOneWidget);
    expect(find.text('Определён: Японский'), findsNothing);
  });

  testWidgets('stays quiet about the language while detection is off', (tester) async {
    final cubits = stage(
      buildCubits(),
      settings: const AppSettings(detectSourceLanguage: false),
      detectedLanguage: 'ja',
    );
    await pumpDashboard(tester, cubits, const Size(1280, 720));

    // The list already states the language; repeating it would be noise.
    expect(find.text('Определён: Японский'), findsNothing);
  });

  testWidgets('shows a phrase as a bubble with its time beside the tail', (tester) async {
    final cubits = stage(
      buildCubits(),
      transcript: const [
        TranscriptEntry(
          original: 'The gate is sealed.',
          english: 'The gate is sealed.',
          translated: 'Ворота закрыты.',
          latency: Duration(milliseconds: 1325),
        ),
      ],
    );
    await pumpDashboard(tester, cubits, const Size(1280, 720));

    expect(find.text('The gate is sealed.'), findsOneWidget);
    expect(find.text('Ворота закрыты.'), findsOneWidget);
    expect(find.text('1325 мс'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets, reason: 'the bubble tail is painted');
  });

  testWidgets('writes a line of the transcript into the glossary', (tester) async {
    final glossary = glossaryShowing(const GlossaryState(loaded: true));
    final cubits = stage(
      buildCubits(glossary: glossary),
      transcript: const [
        TranscriptEntry(
          original: 'Fire in the hole!',
          english: 'Fire in the hole!',
          translated: '\u041e\u0433\u043e\u043d\u044c \u0432 \u0434\u044b\u0440\u0443!',
          latency: Duration(milliseconds: 900),
        ),
      ],
    );
    // Taller than the usual test window: the badge and the button sit under
    // the bubble, and a short one puts them past the bottom edge.
    await pumpDashboard(tester, cubits, const Size(1280, 1000));
    await showTranscript(tester);

    await tester.tap(find.byKey(const ValueKey('transcript-correct-Fire in the hole!')));
    await tester.pumpAndSettle();
    // Opened on what was said, so a correction is a word changed rather than
    // a line retyped.
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('transcript-correction')))
          .controller
          ?.text,
      '\u041e\u0433\u043e\u043d\u044c \u0432 \u0434\u044b\u0440\u0443!',
    );

    await tester.enterText(
      find.byKey(const ValueKey('transcript-correction')),
      '\u041b\u043e\u0436\u0438\u0441\u044c!',
    );
    await tester.tap(find.text('\u0421\u043e\u0445\u0440\u0430\u043d\u0438\u0442\u044c'));
    await tester.pumpAndSettle();

    final written =
        verify(() => glossary.add(captureAny())).captured.single as GlossaryEntryWritten;
    expect(written.entry.kind, GlossaryKind.phrase);
    expect(written.entry.source, 'Fire in the hole!');
    expect(written.entry.reading, '\u041b\u043e\u0436\u0438\u0441\u044c!');
  });

  // The player opens the dialog on a line that came out right and presses
  // save without touching it: that pins the reading, and it used to write
  // nothing at all and say nothing either.
  testWidgets('writes a reading the player left as it was heard', (tester) async {
    final glossary = glossaryShowing(const GlossaryState(loaded: true));
    final cubits = stage(
      buildCubits(glossary: glossary),
      transcript: const [
        TranscriptEntry(
          original: 'Fire in the hole!',
          english: 'Fire in the hole!',
          translated: 'Огонь в дыру!',
          latency: Duration(milliseconds: 900),
        ),
      ],
    );
    await pumpDashboard(tester, cubits, const Size(1280, 1000));
    await showTranscript(tester);

    await tester.tap(find.byKey(const ValueKey('transcript-correct-Fire in the hole!')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    final written =
        verify(() => glossary.add(captureAny())).captured.single as GlossaryEntryWritten;
    expect(written.entry.source, 'Fire in the hole!');
    expect(written.entry.reading, 'Огонь в дыру!');
  });

  testWidgets('passes a line over from the transcript', (tester) async {
    final glossary = glossaryShowing(const GlossaryState(loaded: true));
    final cubits = stage(
      buildCubits(glossary: glossary),
      transcript: const [
        TranscriptEntry(
          original: 'Reloading!',
          english: 'Reloading!',
          translated: 'Перезарядка!',
          latency: Duration(milliseconds: 900),
        ),
      ],
    );
    await pumpDashboard(tester, cubits, const Size(1280, 1000));
    await showTranscript(tester);

    await tester.tap(find.byKey(const ValueKey('transcript-correct-Reloading!')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('transcript-correction-silence')));
    await tester.pumpAndSettle();

    final written =
        verify(() => glossary.add(captureAny())).captured.single as GlossaryEntryWritten;
    expect(written.entry.source, 'Reloading!');
    expect(written.entry.silent, isTrue);
  });

  testWidgets('offers no correction for a line that was never translated', (tester) async {
    final cubits = stage(
      buildCubits(),
      transcript: const [
        TranscriptEntry(
          original: '',
          english: '',
          translated: '\u041e\u0442\u043a\u0440\u043e\u0439 \u0434\u0432\u0435\u0440\u044c.',
          latency: Duration(milliseconds: 300),
        ),
      ],
    );
    await pumpDashboard(tester, cubits, const Size(1280, 720));

    expect(find.byKey(const ValueKey('transcript-correct-')), findsNothing);
  });

  testWidgets('clears the transcript on request', (tester) async {
    const line = TranscriptEntry(
      original: 'The gate is sealed.',
      english: 'The gate is sealed.',
      translated: 'Ворота закрыты.',
      latency: Duration(milliseconds: 1325),
    );
    final lists = transcriptShowing(const TranscriptState(transcript: [line]));
    final cubits = stage(buildCubits(transcript: lists));
    await pumpDashboard(tester, cubits, const Size(1280, 720));
    await showTranscript(tester);
    expect(find.text('Ворота закрыты.'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Очистить'));
    await tester.pumpAndSettle();

    verify(() => lists.add(const TranscriptCleared())).called(1);
  });

  testWidgets('says the transcript is empty once it is', (tester) async {
    final cubits = stage(buildCubits(transcript: transcriptShowing(const TranscriptState())));
    await pumpDashboard(tester, cubits, const Size(1280, 720));
    await showTranscript(tester);

    expect(find.text('Здесь появятся распознанные и переведённые реплики'), findsOneWidget);
  });

  testWidgets('offers nothing to clear while the transcript is empty', (tester) async {
    final cubits = stage(buildCubits());
    await pumpDashboard(tester, cubits, const Size(1280, 720));

    final button = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Очистить'));

    expect(button.onPressed, isNull);
  });

  testWidgets('keeps the session running when the transcript is cleared', (tester) async {
    final session = sessionShowing(const SessionState(status: PipelineStatus.listening));
    final lists = transcriptShowing(
      const TranscriptState(
        transcript: [
          TranscriptEntry(
            original: '',
            english: 'The gate is sealed.',
            translated: 'Ворота закрыты.',
            latency: Duration(milliseconds: 900),
          ),
        ],
      ),
    );
    final cubits = stage(buildCubits(session: session, transcript: lists));
    await pumpDashboard(tester, cubits, const Size(1280, 720));
    await showTranscript(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Очистить'));
    await tester.pumpAndSettle();

    verify(() => lists.add(const TranscriptCleared())).called(1);
    verifyNever(() => session.add(any()));
    expect(find.text('Остановить'), findsOneWidget);
  });

  testWidgets('falls back to the recognized English when there is no original', (tester) async {
    final cubits = stage(
      buildCubits(),
      transcript: const [
        TranscriptEntry(
          original: '',
          english: 'Take cover.',
          translated: 'В укрытие.',
          latency: Duration(milliseconds: 900),
        ),
      ],
    );
    await pumpDashboard(tester, cubits, const Size(1280, 720));

    expect(find.text('Take cover.'), findsOneWidget);
    expect(find.text('900 мс'), findsOneWidget);
  });

  testWidgets('lets the dubbing start as soon as a process is chosen', (tester) async {
    // Capturing one process needs one named, so the button waits for it. It
    // is the only thing on the screen that moves when the player picks one:
    // a listener that skipped the choice used to leave the button grey.
    final cubits = stage(
      buildCubits(),
      settings: const AppSettings(audioCaptureSource: AudioCaptureSource.process),
      models: catalogue(),
    );
    await pumpDashboard(tester, cubits, const Size(1280, 720));

    FilledButton startButton() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Начать перевод'));
    expect(startButton().onPressed, isNull, reason: 'no process named yet');

    cubits.sourcesRepository.select(
      const GameProcess(pid: 4242, name: 'game.exe', path: 'game.exe'),
    );
    // Twice: a cubit reaches its listeners a microtask later than the emit.
    await tester.pump();
    await tester.pump();

    expect(startButton().onPressed, isNotNull);
  });

  testWidgets('says in one card what the dead start button waits for', (tester) async {
    // All three reasons at once, numbered in the order they are met. They
    // used to be a notice for the packages, a notice for the route, and
    // nothing whatever for a game not yet chosen.
    final cubits = stage(
      buildCubits(),
      settings: const AppSettings(captureRouted: false),
      models: catalogue(installed: false),
    );
    await pumpDashboard(tester, cubits, const Size(1280, 720));

    expect(find.text('Чтобы начать'), findsOneWidget);
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('Для первого запуска нужны модели'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
    expect(find.text('Путь не собран'), findsOneWidget);
    expect(find.text('3.'), findsOneWidget);
    expect(find.text('Выберите игру в списке процессов'), findsOneWidget);

    // The package step leads to the screen the packages are on; the game is
    // chosen in the picker above the card, so that step leads nowhere.
    await tester.tap(find.widgetWithText(TextButton, 'Открыть модели'));
    await tester.pumpAndSettle();
    expect(cubits.navigation.state.section, DashboardSection.models);
  });

  testWidgets('takes the card away once nothing is left to ask for', (tester) async {
    final cubits = stage(buildCubits(), models: catalogue());
    cubits.sourcesRepository.select(
      const GameProcess(pid: 4242, name: 'game.exe', path: 'game.exe'),
    );
    await pumpDashboard(tester, cubits, const Size(1280, 720));

    expect(find.text('Чтобы начать'), findsNothing);
  });

  testWidgets('offers Russian alone beside the start button', (tester) async {
    final cubits = stage(buildCubits(), models: catalogue());
    await pumpDashboard(tester, cubits, const Size(1280, 720));

    final picker = find.byKey(const ValueKey('targetLanguage'));
    expect(picker, findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);
    final field = tester.widget<DropdownButtonFormField<String>>(picker);
    expect(field.initialValue, 'ru');
    expect(cubits.selection.requiredModelsInstalled, isTrue);
  });

  testWidgets('marks the language whose models are missing', (tester) async {
    final cubits = stage(buildCubits(), models: catalogue(missingLanguage: 'ru'));
    await pumpDashboard(tester, cubits, const Size(1280, 720));

    expect(cubits.selection.isLanguageReady('ru'), isFalse);

    await tester.tap(find.byKey(const ValueKey('targetLanguage')));
    await tester.pumpAndSettle();
    expect(find.text('Русский · нет моделей'), findsWidgets);
  });

  group('pausing a session', () {
    testWidgets('offers a pause beside a full stop', (tester) async {
      final session = sessionShowing(const SessionState(status: PipelineStatus.listening));
      final cubits = stage(buildCubits(session: session), models: catalogue());
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      expect(find.byKey(const ValueKey('pauseButton')), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Остановить'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('pauseButton')));
      await tester.pumpAndSettle();
      verify(() => session.add(const SessionPaused())).called(1);

      await tester.tap(find.widgetWithText(FilledButton, 'Остановить'));
      await tester.pumpAndSettle();
      verify(() => session.add(const SessionStopped())).called(1);
    });

    testWidgets('says it rests, and offers the resume and the stop', (tester) async {
      final session = sessionShowing(const SessionState(status: PipelineStatus.paused));
      final cubits = stage(buildCubits(session: session), models: catalogue());
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      expect(find.text('Пауза'), findsOneWidget, reason: 'the status says so');
      expect(find.byKey(const ValueKey('stopButton')), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Продолжить'));
      await tester.pumpAndSettle();

      verify(() => session.add(const SessionResumed())).called(1);
    });
  });

  group('the voices of the scene', () {
    const guard = Character(id: 'a1', name: 'Стражник', vector: [0.2, 0.4]);

    StagedDashboard stageScene({
      List<SceneSpeaker> speakers = const [],
      List<Character> characters = const [guard],
    }) {
      final cubits = stage(
        buildCubits(),
        // The whole default output needs no process chosen.
        settings: const AppSettings(audioCaptureSource: AudioCaptureSource.system),
        models: catalogue(),
        speakers: speakers,
      );
      cubits.cast.seed(CharacterLibrary(characters: characters));
      return cubits;
    }

    testWidgets('says nobody has spoken yet', (tester) async {
      await pumpDashboard(tester, stageScene(), const Size(1400, 900));

      expect(find.text('ГОЛОСА СЦЕНЫ'), findsOneWidget);
      expect(find.textContaining('Пока никто не заговорил'), findsOneWidget);
    });

    testWidgets('offers to place the voices before anything is dubbed', (tester) async {
      await pumpDashboard(tester, stageScene(), const Size(1400, 900));

      final listen = find.byKey(const ValueKey('sceneListen'));
      expect(tester.widget<TextButton>(listen).onPressed, isNotNull);
      expect(find.text('Определить голоса'), findsOneWidget);
      expect(find.textContaining('Нажмите «Определить голоса»'), findsOneWidget);
    });

    testWidgets('cannot place them while nothing can hear who is speaking', (tester) async {
      final cubits = stage(
        buildCubits(),
        settings: const AppSettings(audioCaptureSource: AudioCaptureSource.system),
        // The converter is what tells the voices apart.
        models: catalogue(missingLanguage: null)
          ..removeWhere((state) => state.model.kind == ModelKind.voiceConversion),
      );
      await pumpDashboard(tester, cubits, const Size(1400, 900));

      expect(
        tester.widget<TextButton>(find.byKey(const ValueKey('sceneListen'))).onPressed,
        isNull,
      );
      expect(find.textContaining('Голоса различаются конвертером'), findsOneWidget);
    });

    testWidgets('says it is listening while the voices are placed', (tester) async {
      final cubits = stageScene();
      cubits.stageSession(
        const SessionState(
          status: PipelineStatus.listening,
          session: PipelineSession.scene,
        ),
      );
      await pumpDashboard(tester, cubits, const Size(1400, 900));

      expect(find.text('Остановить'), findsOneWidget);
      expect(find.textContaining('Слушаю игру'), findsOneWidget);
    });

    testWidgets('names a voice the bank founded and the card it knows', (tester) async {
      await pumpDashboard(
        tester,
        stageScene(
          speakers: const [
            SceneSpeaker(key: 'timbre:0', line: 'Стоять!', lines: 2),
            SceneSpeaker(key: 'character:a1', line: 'Чего тебе?'),
          ],
        ),
        const Size(1400, 900),
      );

      // The bank counts from zero and the player counts from one.
      expect(find.text('Голос 1'), findsOneWidget);
      expect(find.text('Стражник'), findsOneWidget);
      expect(find.text('Стоять!'), findsOneWidget);
      expect(find.text('2 реплики'), findsOneWidget);
    });

    testWidgets('says who reads a voice of the scene, and offers no choice', (tester) async {
      await pumpDashboard(
        tester,
        stageScene(
          speakers: const [SceneSpeaker(key: 'character:a1', line: 'Стоять!')],
          characters: const [
            Character(id: 'a1', name: 'Стражник', vector: [0.2], voicedBy: 'b2'),
            Character(id: 'b2', name: 'Кузнец', vector: [0.3]),
          ],
        ),
        const Size(1400, 900),
      );

      // Live shows the cast at work as the graph arranged it; changing it is
      // the graph's alone.
      expect(find.byKey(const ValueKey('assign-character:a1')), findsNothing);
      expect(find.byKey(const ValueKey('reads-character:a1')), findsOneWidget);
      expect(find.text('Кузнец'), findsOneWidget);
    });

    testWidgets('offers nothing to a line nobody was heard in', (tester) async {
      await pumpDashboard(
        tester,
        stageScene(
          speakers: const [SceneSpeaker(key: 'voice:eugene', line: 'Привет')],
        ),
        const Size(1400, 900),
      );

      expect(find.text('Без опознания'), findsOneWidget);
      expect(find.byKey(const ValueKey('assign-voice:eugene')), findsNothing);
    });

    testWidgets('says in the transcript who was heard and who reads them', (tester) async {
      await pumpDashboard(
        tester,
        stageScene(
            speakers: const [SceneSpeaker(key: 'character:a1', line: 'Стоять!')],
            characters: const [
              Character(id: 'a1', name: 'Стражник', vector: [0.2], voicedBy: 'b2'),
              Character(id: 'b2', name: 'Кузнец', vector: [0.3]),
            ],
          )
          ..stageSession(const SessionState(status: PipelineStatus.listening))
          ..stageLists(
            const TranscriptState(
              speakers: [SceneSpeaker(key: 'character:a1', line: 'Стоять!')],
              transcript: [
                TranscriptEntry(
                  original: 'Halt!',
                  english: 'Halt!',
                  translated: 'Стоять!',
                  latency: Duration(milliseconds: 900),
                  speaker: 'character:a1',
                ),
              ],
            ),
          ),
        const Size(1400, 900),
      );

      expect(find.text('Стражник'), findsWidgets);
      expect(find.text('Звучит как «Кузнец»'), findsOneWidget);
    });
  });
}
