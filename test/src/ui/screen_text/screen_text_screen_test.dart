// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// The page that reads the screen: its session, its snippets and its frame.

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/model_catalog.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/capture_sources.dart';
import 'package:lore_dub/src/domain/game_process.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/ocr_region.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart'
    show PipelineSession, PipelineStatus, TranscriptEntry;
import 'package:lore_dub/src/domain/screen_reading.dart';
import 'package:lore_dub/src/ui/shell/bloc/navigation_cubit.dart';
import 'package:lore_dub/src/ui/common/bloc/session_bloc.dart';
import 'package:lore_dub/src/ui/common/bloc/transcript_bloc.dart';
import 'package:lore_dub/src/ui/screen_text/screen_language_and_voice.dart';
import 'package:lore_dub/src/ui/screen_text/snippet_only_card.dart';
import 'package:lore_dub/src/ui/screen_text/subtitle_frame_card.dart';
import 'package:lore_dub/src/ui/screen_text/text_language_picker.dart';
import 'package:lore_dub/src/ui/settings/voice_choice_field.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/dashboard_harness.dart';
import '../../../support/key_finders.dart';
import '../../../support/mock_blocs.dart';
import '../../../support/staged_dashboard.dart';

void main() {
  // What `captureAny` stands in with before anything is captured.
  setUpAll(registerEventFallbacks);

  testWidgets('names the screen path on the page that reads the screen', (tester) async {
    final cubits = stage(
      buildCubits(),
      section: DashboardSection.snapshot,
      models: catalogue(),
    );
    await pumpDashboard(tester, cubits, const Size(1280, 900));

    expect(find.text('Windows OCR → English → Marian → Русский → Vosk'), findsOneWidget);
    expect(find.textContaining('Whisper →'), findsNothing);
  });

  testWidgets('offers the text language on the page that reads the screen', (tester) async {
    final cubits = stage(
      buildCubits(),
      section: DashboardSection.snapshot,
      settings: const AppSettings(sourceLanguage: 'ru'),
      models: catalogue(),
    );
    await pumpDashboard(tester, cubits, const Size(1280, 900));

    expect(find.text('Язык текста и озвучки'), findsOneWidget);
    expect(find.text('Определять язык'), findsNothing);
    expect(find.text('Язык озвучки меняется вместе с ним и в «Моделях»'), findsOneWidget);
  });

  testWidgets('moves the dubbing language, and the voices, with the language picked', (
    tester,
  ) async {
    final cubits = stage(
      buildCubits(),
      section: DashboardSection.snapshot,
      settings: const AppSettings(targetLanguage: 'en'),
      models: catalogue(),
    );
    await pumpDashboard(tester, cubits, const Size(1280, 900));
    (String, String) languages() => (
      cubits.settingsRepository.settings.textLanguage,
      cubits.settingsRepository.settings.targetLanguage,
    );
    Future<void> pick(String from, String option) async {
      await tester.tap(find.byKey(ValueKey('textLanguage-$from')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }

    await pick('en-en', 'Русский');
    expect(languages(), ('ru', 'ru'), reason: 'the models screen picks Russian with it');
    expect(find.textContaining('голос (Русский)'), findsOneWidget);
    // Both readings are read in a voice picked out of the Russian ones.
    expect(
      find.byKey(ValueKey('voice-ru-${speechModelFor('ru')!.speaker}')),
      findsOneWidget,
    );

    // Back to English, the voices and the models screen go back with it.
    await pick('ru-ru', 'Английский');
    expect(languages(), ('en', 'en'));
    expect(
      find.byKey(ValueKey('voice-en-${speechModelFor('en')!.speaker}')),
      findsOneWidget,
    );

    await pick('en-en', 'Английский → Русский');
    expect(languages(), ('en', 'ru'), reason: 'English subtitles heard in Russian');
  });

  testWidgets('picks the voice once, beside the language, for both readings', (tester) async {
    final cubits = stage(
      buildCubits(),
      section: DashboardSection.snapshot,
      settings: const AppSettings(targetLanguage: 'ru'),
      models: catalogue(),
    );
    await pumpDashboard(tester, cubits, const Size(1400, 1000));
    final voice = find.descendant(
      of: find.byType(ScreenLanguageAndVoice),
      matching: find.byType(VoiceChoiceField),
    );

    expect(voice, findsOneWidget);
    for (final card in [SnippetOnlyCard, SubtitleFrameCard]) {
      expect(
        find.descendant(of: find.byType(card), matching: find.byType(VoiceChoiceField)),
        findsNothing,
        reason: 'each reading keeps only its start button',
      );
    }
    expect(
      tester.getTopLeft(voice).dy,
      moreOrLessEquals(tester.getTopLeft(find.byType(TextLanguagePicker)).dy),
      reason: 'on the row of the language, in the room it leaves',
    );

    tester
        .widget<DropdownButtonFormField<String>>(
          find.descendant(of: voice, matching: find.byType(DropdownButtonFormField<String>)),
        )
        .onChanged!('male_0');
    await tester.pumpAndSettle();

    expect(cubits.settingsRepository.settings.voice, 'male_0');
  });

  testWidgets('offers only English with no other voice on disk', (tester) async {
    final cubits = stage(
      buildCubits(),
      section: DashboardSection.snapshot,
      settings: const AppSettings(targetLanguage: 'en'),
      models: catalogue(missingLanguage: 'ru'),
    );
    await pumpDashboard(tester, cubits, const Size(1280, 900));

    await tester.tap(find.byKey(const ValueKey('textLanguage-en-en')));
    await tester.pumpAndSettle();

    expect(find.text('Русский'), findsNothing);
    expect(find.text('Английский → Русский'), findsNothing);
  });

  group('the snapshot screen', () {
    const snippet = TranscriptEntry(
      original: 'Press E to open',
      english: 'Press E to open',
      translated: 'Нажмите E, чтобы открыть',
      latency: Duration(milliseconds: 800),
    );

    /// The button of one reading: both by default, the one the whole page
    /// starts with.
    FilledButton startButton(
      WidgetTester tester, {
      ScreenReading reading = ScreenReading.both,
    }) => tester.widget<FilledButton>(find.byKey(ValueKey('snapshotStart-${reading.name}')));

    const game = GameProcess(pid: 4242, name: 'game.exe', path: 'game.exe');

    StagedDashboard stageSnapshot({
      AppSettings settings = const AppSettings(),
      List<ModelInstallState>? models,
      SessionState pipeline = const SessionState(),
      TranscriptState lists = const TranscriptState(),
    }) {
      final cubits = stage(
        buildCubits(),
        section: DashboardSection.snapshot,
        settings: settings,
        models: models ?? catalogue(),
      );
      // The frame is read out of one window, so this session waits for a
      // game as live dubbing does.
      cubits.stageSession(pipeline);
      cubits.stageLists(lists);
      cubits.sourcesRepository.seed(const CaptureSources(processes: [game], selected: game));
      return cubits;
    }

    testWidgets('starts the reading its own button names', (tester) async {
      final session = sessionShowing(const SessionState());
      final cubits = stage(
        buildCubits(session: session),
        section: DashboardSection.snapshot,
        models: catalogue(),
      );
      cubits.sourcesRepository.seed(const CaptureSources(processes: [game], selected: game));
      await pumpDashboard(tester, cubits, const Size(1400, 1000));

      for (final reading in ScreenReading.values) {
        final button = find.byKey(ValueKey('snapshotStart-${reading.name}'));
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        verify(
          () => session.add(ScreenToggled(initializing: false, reading: reading)),
        ).called(1);
      }
    });

    testWidgets('clears the selections by the button over them', (tester) async {
      final lists = transcriptShowing(
        const TranscriptState(
          snapshots: [
            TranscriptEntry(
              original: 'Press E to open',
              english: 'Press E to open',
              translated: 'Нажмите E, чтобы открыть',
              latency: Duration(milliseconds: 800),
            ),
          ],
        ),
      );
      final cubits = stage(
        buildCubits(transcript: lists),
        section: DashboardSection.snapshot,
        models: catalogue(),
      );
      await pumpDashboard(tester, cubits, const Size(1400, 1000));

      final clear = find.byTooltip('Убрать фрагменты из списка');
      await tester.ensureVisible(clear);
      await tester.pumpAndSettle();
      await tester.tap(clear);
      await tester.pumpAndSettle();

      verify(() => lists.add(const SnapshotsCleared())).called(1);
    });

    testWidgets('reads the frame and the selection on one page', (tester) async {
      await pumpDashboard(tester, stageSnapshot(), const Size(1400, 1000));

      expect(find.text('02  /  ТЕКСТ С ЭКРАНА'), findsOneWidget);
      expect(find.text('Экран'), findsOneWidget);
      expect(find.text('Перевод с экрана'), findsOneWidget);
      expect(find.textContaining('Удерживайте'), findsOneWidget);
      expect(keysHeld('Ctrl + Alt + S'), findsOneWidget, reason: 'the key is drawn as keys');
      expect(find.textContaining('субтитры в рамке читаются'), findsOneWidget);
      expect(find.text('Язык текста и озвучки'), findsOneWidget);
      expect(find.text('СУБТИТРЫ'), findsOneWidget);
      expect(find.text('Выделенные фрагменты появятся здесь'), findsOneWidget);
      expect(startButton(tester).onPressed, isNotNull);
      // The frame is drawn here before the game starts, and over the game
      // itself once it has.
      expect(find.byKey(const ValueKey('ocrRegion')), findsOneWidget);
      expect(find.textContaining('удерживайте'), findsOneWidget);
      expect(keysHeld('Ctrl + Alt + F'), findsOneWidget);
    });

    testWidgets('says when a frame drawn over the game missed its window', (tester) async {
      final cubits = stageSnapshot(
        pipeline: const SessionState(
          status: PipelineStatus.listening,
          session: PipelineSession.screen,
          frameMissed: true,
        ),
      );
      await pumpDashboard(tester, cubits, const Size(1400, 1000));

      expect(
        find.text('Выделение не попало в окно игры — рамка осталась прежней'),
        findsOneWidget,
      );
    });

    testWidgets('reads the whole screen without a game to name', (tester) async {
      // A game that keeps no ordinary window has none to read out of, and
      // the frame is then measured against the monitors themselves.
      final cubits = stageSnapshot(settings: const AppSettings());
      cubits.sourcesRepository.seed(const CaptureSources());
      await pumpDashboard(tester, cubits, const Size(1400, 1000));
      expect(startButton(tester).onPressed, isNull, reason: 'a window needs a game');

      await tester.tap(find.text('Весь экран'));
      await tester.pumpAndSettle();

      expect(cubits.settings.settings.readsWholeScreen, isTrue);
      expect(startButton(tester).onPressed, isNotNull);
      expect(find.textContaining('Читается всё, что на экране'), findsOneWidget);
      expect(find.textContaining('% экрана'), findsOneWidget, reason: 'the frame says of what');
      // There is no window to read out of, so no game is asked for.
      expect(find.text('Выберите игру, чтобы читать её экран'), findsNothing);
      expect(
        tester.widget<DropdownMenu<GameProcess>>(find.byType(DropdownMenu<GameProcess>)).enabled,
        isFalse,
      );
    });

    // The page scrolls rather than squeezing what it holds, and a window
    // of any shape was overflowing it before it did: the frame card grew
    // and the heading of a list did not give way.
    for (final size in const [
      Size(900, 700),
      Size(1100, 900),
      Size(1400, 1000),
      Size(1400, 1300),
      Size(1920, 1080),
    ]) {
      testWidgets('fits a window of ${size.width} by ${size.height}', (tester) async {
        final overflows = <String>[];
        final reported = FlutterError.onError;
        FlutterError.onError = (details) => overflows.add(details.exceptionAsString());
        await pumpDashboard(tester, stageSnapshot(), size);
        FlutterError.onError = reported;

        expect(overflows, isEmpty);
      });
    }

    testWidgets('stacks the language and its note where the card is narrow', (tester) async {
      // Narrow enough that the language and its note no longer share a
      // line: fixed at both halves, the row used to overflow.
      await pumpDashboard(tester, stageSnapshot(), const Size(480, 1000));

      final field = find.byKey(const ValueKey('textLanguage-en-ru'));
      final note = find.text(
        'Язык озвучки меняется вместе с ним и в «Моделях»',
      );
      expect(field, findsOneWidget);
      expect(
        tester.getTopLeft(note).dy,
        greaterThan(tester.getBottomLeft(field).dy - 1),
        reason: 'the note went under the field rather than off the card',
      );
    });

    testWidgets('waits for the game whose window it reads', (tester) async {
      final cubits = stageSnapshot();
      cubits.sourcesRepository.seed(const CaptureSources());
      await pumpDashboard(tester, cubits, const Size(1400, 1000));

      expect(find.text('Выберите игру, чтобы читать её экран'), findsOneWidget);
      expect(startButton(tester).onPressed, isNull);
    });

    testWidgets('needs the translator and the voice, not whisper', (tester) async {
      final cubits = stageSnapshot(
        models: [
          for (final model in modelCatalog)
            ModelInstallState(model: model, installed: model.kind != ModelKind.recognition),
        ],
      );
      await pumpDashboard(tester, cubits, const Size(1400, 1000));

      expect(find.text('Для первого запуска нужны модели'), findsNothing);
      expect(startButton(tester).onPressed, isNotNull);
    });

    testWidgets('cannot start without a key to select with', (tester) async {
      final cubits = stageSnapshot(
        settings: const AppSettings().withHotkey(HotkeyAction.snapshot, null),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      expect(find.text('Клавиша выделения не назначена.'), findsOneWidget);
      expect(startButton(tester).onPressed, isNull);
    });

    testWidgets('shows what was selected while the session waits', (tester) async {
      final cubits = stageSnapshot(
        pipeline: const SessionState(
          status: PipelineStatus.listening,
          session: PipelineSession.screen,
        ),
        lists: const TranscriptState(snapshots: [snippet]),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      expect(find.text('Нажмите E, чтобы открыть'), findsOneWidget);
      expect(find.text('Читаю экран'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Остановить'), findsOneWidget);
    });

    testWidgets('says when the selection held no text', (tester) async {
      final cubits = stageSnapshot(
        pipeline: const SessionState(
          status: PipelineStatus.listening,
          session: PipelineSession.screen,
        ),
        lists: const TranscriptState(snapshotMissed: true),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      expect(find.text('В выделенной области текст не найден'), findsOneWidget);
    });

    testWidgets('leaves the key to live dubbing while it runs', (tester) async {
      final cubits = stageSnapshot(
        pipeline: const SessionState(status: PipelineStatus.listening),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      expect(find.text('Идёт «Эфир» — клавиша выделения работает и в нём'), findsOneWidget);
      expect(startButton(tester).onPressed, isNull);
    });

    testWidgets('lets Live take the worker over', (tester) async {
      final cubits = stage(
        buildCubits(),
        settings: const AppSettings(audioCaptureSource: AudioCaptureSource.system),
        models: catalogue(),
      );
      cubits.stageSession(
        const SessionState(
          status: PipelineStatus.listening,
          session: PipelineSession.screen,
        ),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      expect(find.byKey(const ValueKey('pauseButton')), findsNothing);
      final start = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Начать перевод'),
      );
      expect(start.onPressed, isNotNull);
    });
  });

  group('the subtitle area', () {
    Future<StagedDashboard> pumpSubtitleArea(
      WidgetTester tester, {
      OcrRegion region = OcrRegion.standard,
      PipelineStatus status = PipelineStatus.idle,
    }) async {
      final cubits = stage(
        buildCubits(),
        section: DashboardSection.snapshot,
        settings: AppSettings(ocrRegion: region),
        models: catalogue(),
        status: status,
      );
      await pumpDashboard(tester, cubits, const Size(1280, 1000));
      await tester.ensureVisible(find.byKey(const ValueKey('ocrRegionScreen')));
      await tester.pumpAndSettle();
      return cubits;
    }

    /// A point on the scaled-down screen, as a fraction of its sides.
    Offset onScreen(WidgetTester tester, double x, double y) {
      final screen = tester.getRect(find.byKey(const ValueKey('ocrRegionScreen')));
      return Offset(screen.left + screen.width * x, screen.top + screen.height * y);
    }

    Future<void> dragOnScreen(WidgetTester tester, Offset from, Offset to) async {
      await tester.dragFrom(from, to - from, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
    }

    void expectRegion(OcrRegion actual, OcrRegion expected) {
      expect(actual.left, closeTo(expected.left, 0.01));
      expect(actual.top, closeTo(expected.top, 0.01));
      expect(actual.right, closeTo(expected.right, 0.01));
      expect(actual.bottom, closeTo(expected.bottom, 0.01));
    }

    testWidgets('draws a new frame dragged across empty screen', (tester) async {
      final cubits = await pumpSubtitleArea(tester);

      await dragOnScreen(tester, onScreen(tester, 0.1, 0.1), onScreen(tester, 0.6, 0.4));

      const drawn = OcrRegion(left: 0.1, top: 0.1, right: 0.6, bottom: 0.4);
      expectRegion(cubits.settings.settings.ocrRegion, drawn);
      expectRegion((await SettingsService().load()).ocrRegion, drawn);
      expect(find.text('Рамка 50 × 30% окна, отступ 10% слева и 10% сверху'), findsOneWidget);
    });

    testWidgets('moves the frame it is dragged by without resizing it', (tester) async {
      final cubits = await pumpSubtitleArea(
        tester,
        region: const OcrRegion(left: 0.2, top: 0.6, right: 0.6, bottom: 0.9),
      );

      await dragOnScreen(tester, onScreen(tester, 0.4, 0.75), onScreen(tester, 0.5, 0.65));

      expectRegion(
        cubits.settings.settings.ocrRegion,
        const OcrRegion(left: 0.3, top: 0.5, right: 0.7, bottom: 0.8),
      );
    });

    testWidgets('resizes the frame by its corner', (tester) async {
      final cubits = await pumpSubtitleArea(
        tester,
        region: const OcrRegion(left: 0.2, top: 0.6, right: 0.6, bottom: 0.9),
      );

      await dragOnScreen(tester, onScreen(tester, 0.6, 0.9), onScreen(tester, 0.8, 0.95));

      expectRegion(
        cubits.settings.settings.ocrRegion,
        const OcrRegion(left: 0.2, top: 0.6, right: 0.8, bottom: 0.95),
      );
    });

    testWidgets('puts the default band back', (tester) async {
      final cubits = await pumpSubtitleArea(
        tester,
        region: const OcrRegion(left: 0.2, top: 0.6, right: 0.6, bottom: 0.9),
      );

      await tester.tap(find.text('Сбросить'));
      await tester.pumpAndSettle();

      expect(cubits.settings.settings.ocrRegion, OcrRegion.standard);
    });

    testWidgets('leaves the frame alone while dubbing', (tester) async {
      final cubits = await pumpSubtitleArea(tester, status: PipelineStatus.listening);

      await dragOnScreen(tester, onScreen(tester, 0.1, 0.1), onScreen(tester, 0.6, 0.4));

      expect(cubits.settings.settings.ocrRegion, OcrRegion.standard);
    });
  });
}
