// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lore_dub/l10n/app_localizations.dart';
import 'package:lore_dub/src/app.dart';
import 'package:lore_dub/src/domain/spoken_language.dart';
import 'package:lore_dub/src/data/repositories/app_repository.dart';
import 'package:lore_dub/src/data/repositories/model_repository.dart';
import 'package:lore_dub/src/data/repositories/runtime_repository.dart';
import 'package:lore_dub/src/data/repositories/update_repository.dart';
import 'package:lore_dub/src/data/services/model_catalog.dart';
import 'package:lore_dub/src/data/services/model_storage_service.dart';
import 'package:lore_dub/src/data/services/native_engine_service.dart';
import 'package:lore_dub/src/data/services/runtime_catalog.dart';
import 'package:lore_dub/src/data/services/runtime_storage_service.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/data/services/notification_service.dart';
import 'package:lore_dub/src/data/services/update_service.dart';
import 'package:lore_dub/src/domain/app_release.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/compute_device.dart';
import 'package:lore_dub/src/domain/download_control.dart';
import 'package:lore_dub/src/domain/failure.dart';
import 'package:lore_dub/src/domain/game_process.dart';
import 'package:lore_dub/src/domain/glossary.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/ocr_region.dart';
import 'package:lore_dub/src/domain/pipeline_graph.dart';
import 'package:lore_dub/src/domain/saved_pipeline.dart';
import 'package:lore_dub/src/domain/character.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart'
    show PipelineSession, PipelineStatus, SceneSpeaker, TranscriptEntry;
import 'package:lore_dub/src/ui/dashboard/character_tiles.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/characters_cubit.dart';
import 'package:lore_dub/src/domain/runtime_package.dart';
import 'package:lore_dub/src/ui/dashboard/dashboard_view.dart';
import 'package:lore_dub/src/ui/dashboard/pipeline_canvas.dart';
import 'package:lore_dub/src/ui/dashboard/pipeline_inspector.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/dashboard_cubits.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/downloads_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/glossary_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/pipeline_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/pipeline_graph_bloc.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/settings_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/shell_cubit.dart';
import 'package:lore_dub/src/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  DashboardCubits buildCubits({RuntimeRepository? runtimes}) {
    SharedPreferences.setMockInitialValues({});
    final cubits = DashboardCubits(
      AppRepository(NativeEngineService(), SettingsService()),
      ModelRepository(ModelStorageService()),
      runtimes ?? RuntimeRepository(RuntimeStorageService()),
      UpdateRepository(UpdateService(client: _offline), NotificationService(plugin: _silent)),
    );
    addTearDown(cubits.dispose);
    return cubits;
  }

  /// Puts a state on the screen without running the load that would produce
  /// it. The first load never finishes inside a widget test — it reads the
  /// disk — so what the widgets read is seeded instead.
  DashboardCubits stage(
    DashboardCubits cubits, {
    DashboardSection section = DashboardSection.live,
    UpdateState updates = const UpdateState(),
    AppSettings? settings,
    List<ModelInstallState>? models,
    List<RuntimeInstallState>? runtimes,
    ComputeAvailability? availability,
    PipelineStatus status = PipelineStatus.idle,
    List<TranscriptEntry> transcript = const [],
    List<SceneSpeaker> speakers = const [],
    String? detectedLanguage,
    double? startupProgress,
    String startupStage = '',
  }) {
    cubits.shell.seed(ShellState(section: section, initializing: false, updates: updates));
    if (settings != null) cubits.settings.seed(SettingsState(settings: settings));
    if (models != null || runtimes != null || availability != null) {
      cubits.downloads.seed(
        DownloadsState(
          models: models ?? const [],
          runtimes: runtimes ?? const [],
          availability: availability ?? const ComputeAvailability(),
        ),
      );
    }
    cubits.pipeline.seed(
      LivePipelineState(
        status: status,
        transcript: transcript,
        speakers: speakers,
        detectedLanguage: detectedLanguage,
        startupProgress: startupProgress,
        startupStage: startupStage,
      ),
    );
    return cubits;
  }

  /// Every package in the catalogue, installed unless a language is named.
  List<ModelInstallState> catalogue({bool installed = true, String? missingLanguage}) => [
    for (final model in modelCatalog)
      ModelInstallState(
        model: model,
        // Whisper carries no language, so it is never the missing one.
        installed: installed && (missingLanguage == null || model.language != missingLanguage),
      ),
  ];

  /// Drives the dashboard from cubits the test owns, so pipeline states can
  /// be shown without starting anything.
  Future<void> pumpDashboard(WidgetTester tester, DashboardCubits cubits, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLoreDubTheme(),
        locale: const Locale(defaultInterfaceLanguage),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: DashboardView(cubits: cubits),
      ),
    );
    await tester.pump();
  }

  /// One page's own list. The navigation beside it scrolls too, so the first
  /// scrollable in the tree is not the one a page's test means. Inside the
  /// list, the first is: a card may hold a scroller of its own -- the
  /// stage-by-device table scrolls sideways -- and the list's is above them.
  Finder pageScroller(String key) =>
      find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Scrollable)).first;

  Finder settingsScroller() => pageScroller('settingsList');

  Finder modelsScroller() => pageScroller('modelsList');

  Finder glossaryScroller() => pageScroller('glossaryList');

  Future<void> pumpLoreDub(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const LoreDubBootstrap());
    await tester.pump();
  }

  testWidgets('renders the branded desktop shell', (tester) async {
    await pumpLoreDub(tester, const Size(1280, 720));

    expect(find.text('LoreDub'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Перевод игры'), findsOneWidget);
    expect(find.text('Эфир'), findsOneWidget);
    expect(find.text('01  /  ЖИВОЙ ГОЛОС'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('draws a scaled interface inside the window it was given', (tester) async {
    // A magnified interface reflows in a smaller window and is drawn back
    // over the real one. Laid out at the window's own size first, it was
    // magnified past the edge and the right of every screen was lost.
    SharedPreferences.setMockInitialValues({'interfaceScale': 1.25});
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const LoreDubBootstrap());
    await tester.pump();

    expect(tester.getSize(find.byType(DashboardView)), const Size(1120, 720));
  });

  testWidgets('scrolls the navigation rather than overflowing a short window', (tester) async {
    // Six entries under two headings are taller than a short window, and the
    // panel used to overflow rather than let them scroll. The pump itself is
    // the assertion -- an overflow is an exception the test would fail on.
    await pumpLoreDub(tester, const Size(1280, 560));

    expect(find.text('Эфир'), findsOneWidget);
    expect(find.text('Настройки'), findsOneWidget);
  });

  testWidgets('uses compact navigation in a narrow window', (tester) async {
    await pumpLoreDub(tester, const Size(760, 720));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Эфир'), findsOneWidget);
    expect(find.text('Модели'), findsOneWidget);
    expect(find.text('Настройки'), findsOneWidget);
  });

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
    cubits.pipeline.seed(
      LivePipelineState(
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
    cubits.characters.seed(
      const CharactersState(loading: false, status: PipelineStatus.listening),
    );
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
        stage(
          buildCubits(),
          section: DashboardSection.settings,
          settings: settings,
          models: catalogue(),
        ),
        const Size(1280, 1000),
      );
      await tester.scrollUntilVisible(
        find.text('Оригинальный звук'),
        300,
        scrollable: settingsScroller(),
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
    expect(find.text('Whisper → English → Marian → Русский → Silero'), findsOneWidget);
  });

  testWidgets('names the screen path on the page that reads the screen', (tester) async {
    final cubits = stage(
      buildCubits(),
      section: DashboardSection.snapshot,
      models: catalogue(),
    );
    await pumpDashboard(tester, cubits, const Size(1280, 900));

    expect(find.text('Windows OCR → English → Marian → Русский → Silero'), findsOneWidget);
    expect(find.textContaining('Whisper →'), findsNothing);
  });

  testWidgets('names the original language instead of detecting it', (tester) async {
    await pumpLoreDub(tester, const Size(1280, 720));

    final dropdown = find.byKey(const ValueKey('sourceLanguage'));
    expect(find.text('Определять язык'), findsOneWidget);
    expect(tester.widget<DropdownButtonFormField<String>>(dropdown).onChanged, isNull);

    await tester.tap(find.byType(Switch));
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

    await cubits.pipeline.toggle(initializing: false);
    await tester.pumpAndSettle();

    expect(cubits.pipeline.state.detectedLanguage, isNull);
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
    final cubits = stage(
      buildCubits(),
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

    final written = cubits.glossary.state.glossary.match(
      GlossaryKind.phrase,
      'Fire in the hole!',
    );
    expect(written?.reading, '\u041b\u043e\u0436\u0438\u0441\u044c!');
  });

  // The player opens the dialog on a line that came out right and presses
  // save without touching it: that pins the reading, and it used to write
  // nothing at all and say nothing either.
  testWidgets('writes a reading the player left as it was heard', (tester) async {
    final cubits = stage(
      buildCubits(),
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

    await tester.tap(find.byKey(const ValueKey('transcript-correct-Fire in the hole!')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    final written = cubits.glossary.state.glossary.match(
      GlossaryKind.phrase,
      'Fire in the hole!',
    );
    expect(written?.reading, 'Огонь в дыру!');
  });

  // What the entry is filed under is shown rather than edited, but a phrase
  // written down here is wanted elsewhere, so it can be selected and copied.
  testWidgets('lets a glossary phrase be selected', (tester) async {
    final cubits = stage(buildCubits(), section: DashboardSection.glossary);
    cubits.glossary.seed(
      const GlossaryState(
        loaded: true,
        glossary: Glossary(
          entries: [
            GlossaryEntry(
              kind: GlossaryKind.phrase,
              source: 'Fire in the hole!',
              reading: 'Ложись!',
            ),
          ],
        ),
      ),
    );
    await pumpDashboard(tester, cubits, const Size(1280, 1000));

    expect(
      find.descendant(
        of: find.byType(SelectableText),
        matching: find.text('Fire in the hole!'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('makes a glossary pack and fills it from the lists', (tester) async {
    final cubits = stage(buildCubits(), section: DashboardSection.glossary);
    cubits.glossary.seed(
      const GlossaryState(
        loaded: true,
        glossary: Glossary(
          entries: [
            GlossaryEntry(
              kind: GlossaryKind.phrase,
              source: 'Fire in the hole!',
              reading: 'Ложись!',
            ),
          ],
        ),
      ),
    );
    await pumpDashboard(tester, cubits, const Size(1400, 1000));

    final add = find.byKey(const ValueKey('glossary-pack-add'));
    await tester.scrollUntilVisible(add, 300, scrollable: glossaryScroller());
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();

    expect(cubits.glossary.state.glossary.packs, hasLength(1));
    // A new pack is empty and switched off: it must not narrow the glossary
    // the moment it is made.
    expect(cubits.glossary.state.glossary.packs.single.entryKeys, isEmpty);
    expect(cubits.glossary.state.glossary.inUse.entries, hasLength(1));
  });

  // The whole point of the switch: with a pack on, the dubbing is checked
  // against that pack and nothing else.
  testWidgets('narrows the glossary to the pack that is switched on', (tester) async {
    const fire = GlossaryEntry(
      kind: GlossaryKind.phrase,
      source: 'Fire in the hole!',
      reading: 'Ложись!',
    );
    const megaton = GlossaryEntry(
      kind: GlossaryKind.name,
      source: 'Megaton',
      reading: 'Мегатон',
    );
    final cubits = stage(buildCubits(), section: DashboardSection.glossary);
    cubits.glossary.seed(
      GlossaryState(
        loaded: true,
        glossary: Glossary(
          entries: const [fire, megaton],
          packs: [
            GlossaryPack(id: 'p1', name: 'Fallout', entryKeys: [megaton.packKey]),
          ],
        ),
      ),
    );
    await pumpDashboard(tester, cubits, const Size(1400, 1000));

    final toggle = find.byKey(const ValueKey('glossary-pack-active-p1'));
    await tester.scrollUntilVisible(toggle, 300, scrollable: glossaryScroller());
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(cubits.glossary.state.glossary.inUse.entries, [megaton]);
  });

  // A pack is chosen while looking at what goes into it, so it stands beside
  // the lists where the window is wide enough to hold both.
  testWidgets('stands the packs beside the lists and under them when narrow', (tester) async {
    Future<double> widthAt(WidgetTester tester, Size size) async {
      final cubits = stage(buildCubits(), section: DashboardSection.glossary);
      cubits.glossary.seed(const GlossaryState(loaded: true));
      await pumpDashboard(tester, cubits, size);
      final packs = find.byKey(const ValueKey('glossaryPacks'));
      await tester.scrollUntilVisible(packs, 300, scrollable: glossaryScroller());
      await tester.pumpAndSettle();
      return tester.getSize(packs).width;
    }

    expect(await widthAt(tester, const Size(1400, 1000)), lessThan(400));
    expect(await widthAt(tester, const Size(1000, 1000)), greaterThan(600));
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

    await tester.tap(find.widgetWithText(TextButton, 'Очистить'));
    await tester.pumpAndSettle();

    expect(cubits.pipeline.state.transcript, isEmpty);
    expect(find.text('Ворота закрыты.'), findsNothing);
    expect(
      find.text('Здесь появятся распознанные и переведённые реплики'),
      findsOneWidget,
      reason: 'the empty state comes back',
    );
  });

  testWidgets('offers nothing to clear while the transcript is empty', (tester) async {
    final cubits = stage(buildCubits());
    await pumpDashboard(tester, cubits, const Size(1280, 720));

    final button = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Очистить'));

    expect(button.onPressed, isNull);
  });

  testWidgets('keeps the session running when the transcript is cleared', (tester) async {
    final cubits = stage(
      buildCubits(),
      status: PipelineStatus.listening,
      transcript: const [
        TranscriptEntry(
          original: '',
          english: 'The gate is sealed.',
          translated: 'Ворота закрыты.',
          latency: Duration(milliseconds: 900),
        ),
      ],
    );
    await pumpDashboard(tester, cubits, const Size(1280, 720));

    await tester.tap(find.widgetWithText(TextButton, 'Очистить'));
    await tester.pumpAndSettle();

    expect(cubits.pipeline.state.transcript, isEmpty);
    expect(cubits.pipeline.state.status, PipelineStatus.listening);
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

    cubits.pipeline.selectProcess(
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
    expect(cubits.shell.state.section, DashboardSection.models);
  });

  testWidgets('takes the card away once nothing is left to ask for', (tester) async {
    final cubits = stage(buildCubits(), models: catalogue());
    cubits.pipeline.selectProcess(
      const GameProcess(pid: 4242, name: 'game.exe', path: 'game.exe'),
    );
    await pumpDashboard(tester, cubits, const Size(1280, 720));

    expect(find.text('Чтобы начать'), findsNothing);
  });

  testWidgets('picks the dubbing language beside the start button', (tester) async {
    final cubits = stage(buildCubits(), models: catalogue(missingLanguage: 'de'));
    await pumpDashboard(tester, cubits, const Size(1280, 720));

    final picker = find.byKey(const ValueKey('targetLanguage'));
    expect(picker, findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);

    final field = tester.widget<DropdownButtonFormField<String>>(picker);
    field.onChanged!('fr');
    await tester.pumpAndSettle();

    // The choice is the models choice: the French pair is now the one used.
    expect(cubits.settings.settings.targetLanguage, 'fr');
    expect((await SettingsService().load()).targetLanguage, 'fr');
    expect(cubits.selection.requiredModelsInstalled, isTrue);
  });

  testWidgets('marks a language whose models are missing', (tester) async {
    final cubits = stage(buildCubits(), models: catalogue(missingLanguage: 'de'));
    await pumpDashboard(tester, cubits, const Size(1280, 720));

    expect(cubits.selection.isLanguageReady('ru'), isTrue);
    expect(cubits.selection.isLanguageReady('de'), isFalse);

    await tester.tap(find.byKey(const ValueKey('targetLanguage')));
    await tester.pumpAndSettle();
    expect(find.text('Немецкий · нет моделей'), findsWidgets);
  });

  testWidgets('splits the models screen into recognition, languages and the converter', (
    tester,
  ) async {
    final cubits = stage(
      buildCubits(),
      section: DashboardSection.models,
      models: catalogue(installed: false),
    );
    await pumpDashboard(tester, cubits, const Size(1280, 900));

    expect(find.text('РАСПОЗНАВАНИЕ РЕЧИ'), findsOneWidget);
    expect(find.text('base'), findsOneWidget, reason: 'the whisper builds are bars on a chart');

    // The tiles sit below the fold of a lazy list.
    await tester.scrollUntilVisible(find.text('ЯЗЫКИ ОЗВУЧКИ'), 400, scrollable: modelsScroller());
    expect(find.text('ЯЗЫКИ ОЗВУЧКИ'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('ГОЛОС ОРИГИНАЛА'),
      400,
      scrollable: modelsScroller(),
    );
    expect(find.text('ГОЛОС ОРИГИНАЛА'), findsOneWidget);
    final selection = cubits.selection;
    expect(selection.recognitionModels.length, greaterThan(1), reason: 'the model is a choice');
    expect(selection.languagePairs.length, greaterThan(1));
  });

  group('the language tiles', () {
    Future<DashboardCubits> pumpTiles(
      WidgetTester tester, {
      List<ModelInstallState>? models,
      AppSettings settings = const AppSettings(),
      PipelineStatus status = PipelineStatus.idle,
    }) async {
      final cubits = stage(
        buildCubits(),
        section: DashboardSection.models,
        settings: settings,
        models: models ?? catalogue(missingLanguage: 'de'),
        status: status,
      );
      await pumpDashboard(tester, cubits, const Size(1280, 1000));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('languageTile-uk')),
        300,
        scrollable: modelsScroller(),
      );
      await tester.pumpAndSettle();
      return cubits;
    }

    Finder tile(String language) => find.byKey(ValueKey('languageTile-$language'));
    Finder on(String language, Finder what) => find.descendant(of: tile(language), matching: what);

    testWidgets('holds a translator and a voice in one tile per language', (tester) async {
      await pumpTiles(tester);

      for (final language in ['ru', 'de', 'es', 'fr', 'uk']) {
        expect(tile(language), findsOneWidget, reason: language);
      }
      expect(on('ru', find.text('Русский')), findsOneWidget);
      expect(on('ru', find.text('перевод')), findsOneWidget);
      expect(on('ru', find.text('голос')), findsOneWidget);
      expect(on('ru', find.byTooltip('Удалить')), findsOneWidget);
      expect(on('de', find.byTooltip('Скачать')), findsOneWidget, reason: 'German is missing');
      expect(on('de', find.byTooltip('Удалить')), findsNothing);
    });

    testWidgets('picks the language by tapping its tile', (tester) async {
      final cubits = await pumpTiles(tester);

      await tester.tap(on('de', find.text('Немецкий')));
      await tester.pumpAndSettle();
      expect(cubits.settings.settings.targetLanguage, 'de');

      await tester.tap(on('ru', find.text('Русский')));
      await tester.pumpAndSettle();
      expect(cubits.settings.settings.targetLanguage, 'ru');
    });

    testWidgets('marks the language in use dark and the others light', (tester) async {
      await pumpTiles(tester);

      Color face(String language) => tester
          .widget<Material>(
            find.descendant(of: tile(language), matching: find.byType(Material)).first,
          )
          .color!;
      expect(face('ru'), LoreDubPalette.graphite);
      expect(face('fr'), LoreDubPalette.panel);
    });

    testWidgets('shows a pair downloading as one ring with its controls', (tester) async {
      final translation = translationModelFor('ru')!;
      final speech = speechModelFor('ru')!;
      await pumpTiles(
        tester,
        models: [
          for (final model in modelCatalog)
            model.id == speech.id
                ? ModelInstallState(model: model, progress: 0.5)
                : ModelInstallState(model: model, installed: true),
        ],
      );

      final share =
          (translation.downloadBytes + speech.downloadBytes * 0.5) /
          (translation.downloadBytes + speech.downloadBytes);
      expect(on('ru', find.text('${(share * 100).round()}%')), findsOneWidget);
      expect(on('ru', find.byTooltip('Приостановить')), findsOneWidget);
      expect(on('ru', find.byTooltip('Отменить')), findsOneWidget);
      expect(on('ru', find.byTooltip('Удалить')), findsNothing, reason: 'not while it downloads');
    });

    testWidgets('asks before deleting a language', (tester) async {
      final cubits = await pumpTiles(tester);

      await tester.tap(on('ru', find.byTooltip('Удалить')));
      await tester.pumpAndSettle();
      expect(find.text('Удалить язык?'), findsOneWidget);
      expect(find.textContaining('языка «Русский»'), findsOneWidget);

      await tester.tap(find.text('Оставить'));
      await tester.pumpAndSettle();
      expect(cubits.selection.isLanguageReady('ru'), isTrue);
    });

    testWidgets('keeps the language in use while dubbing runs', (tester) async {
      await pumpTiles(tester, status: PipelineStatus.listening);

      final locked = on('ru', find.byTooltip('Выбранную модель нельзя удалить, пока идёт озвучка'));
      expect(locked, findsOneWidget);
      expect(
        // The button builds its tooltip inside itself.
        tester
            .widget<IconButton>(find.ancestor(of: locked, matching: find.byType(IconButton)))
            .onPressed,
        isNull,
      );
    });

    testWidgets('draws the converter as a tile in use with the original voice', (tester) async {
      await pumpTiles(tester, settings: const AppSettings().withVoiceMode(VoiceMode.original));
      final converter = find.byKey(const ValueKey('converterTile-$voiceConverterModelId'));
      await tester.scrollUntilVisible(converter, 300, scrollable: modelsScroller());
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: converter, matching: find.text('конвертер голоса')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Material>(find.descendant(of: converter, matching: find.byType(Material)).first)
            .color,
        LoreDubPalette.graphite,
      );
    });
  });

  testWidgets('needs only the pair of the chosen language', (tester) async {
    final cubits = stage(
      buildCubits(),
      models: [
        for (final model in modelCatalog)
          ModelInstallState(
            model: model,
            installed: model.language == null || model.language == 'ru',
          ),
      ],
    );
    await pumpDashboard(tester, cubits, const Size(1280, 720));

    expect(cubits.settings.settings.targetLanguage, 'ru');
    expect(cubits.selection.requiredModelsInstalled, isTrue);

    await cubits.settings.selectTargetLanguage('de');

    expect(
      cubits.selection.requiredModelsInstalled,
      isFalse,
      reason: 'the German pair has not been downloaded',
    );
  });

  testWidgets('starts in Russian and remembers a switch to English', (tester) async {
    await pumpLoreDub(tester, const Size(1280, 900));

    expect(find.text('Перевод игры'), findsOneWidget);
    expect((await SettingsService().load()).interfaceLanguage, 'ru');

    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('Signal setup'), findsOneWidget);
    expect(find.text('Interface language'), findsOneWidget);
    expect((await SettingsService().load()).interfaceLanguage, 'en');

    await tester.tap(find.text('Live'));
    await tester.pumpAndSettle();
    expect(find.text('Game dubbing'), findsOneWidget);
    expect(find.text('Start dubbing'), findsOneWidget);
  });

  testWidgets('puts the downloads and the paths side by side at the foot', (tester) async {
    await pumpLoreDub(tester, const Size(1280, 900));
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();

    final downloads = find.text('ЗАГРУЗКА');
    await tester.scrollUntilVisible(downloads, 300, scrollable: settingsScroller());
    await tester.pumpAndSettle();

    expect(find.text('ПУТИ'), findsOneWidget);
    expect(find.text('Загрузка моделей'), findsOneWidget, reason: 'nothing is folded away');
    expect(
      tester.getTopLeft(find.text('ПУТИ')).dx,
      greaterThan(tester.getTopLeft(downloads).dx),
      reason: 'the paths stand beside the downloads, not under them',
    );
  });

  testWidgets('saves a model download proxy from settings', (tester) async {
    await pumpLoreDub(tester, const Size(1280, 900));
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();

    final proxyField = find.widgetWithText(
      TextFormField,
      'HTTP / SOCKS5 proxy',
    );
    // Scrolled to rather than dragged by a fixed distance: the settings list
    // grows with every card added to it.
    await tester.scrollUntilVisible(proxyField, 300, scrollable: settingsScroller());
    await tester.pumpAndSettle();
    await tester.enterText(
      proxyField,
      'http://127.0.0.1:7890',
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Сохранить'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('modelProxyUrl'),
      'http://127.0.0.1:7890',
    );
  });

  testWidgets('offers the compute device presets and a row per stage', (tester) async {
    await pumpLoreDub(tester, const Size(1280, 900));
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();

    final section = find.text('Вычислительное устройство');
    await tester.scrollUntilVisible(section, 300, scrollable: settingsScroller());
    await tester.pumpAndSettle();

    expect(section, findsOneWidget);
    for (final preset in ['Автоматически', 'GPU', 'CPU']) {
      expect(find.text(preset), findsWidgets, reason: preset);
    }
    // One row per stage, named as the player knows them.
    expect(find.text('Whisper'), findsOneWidget);
    expect(find.text('Перевод'), findsOneWidget);
    expect(find.text('Озвучка'), findsOneWidget);
  });

  testWidgets('says what the compute choice leaves to say, and nothing else', (tester) async {
    Future<void> open(WidgetTester tester, ComputeDevice device) async {
      final cubits = stage(
        buildCubits(),
        section: DashboardSection.settings,
        settings: AppSettings(computeDevice: device),
        models: catalogue(),
        availability: const ComputeAvailability(
          adapters: [GraphicsAdapter(name: 'RTX 4070', vendor: GraphicsVendor.nvidia)],
        ),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 1000));
      final section = find.text('Вычислительное устройство');
      await tester.scrollUntilVisible(section, 300, scrollable: settingsScroller());
      await tester.pumpAndSettle();
    }

    // Automatic says neither: the table under it already shows where every
    // stage ended up, which is the answer either line would have given.
    await open(tester, ComputeDevice.auto);
    expect(find.textContaining('RTX 4070'), findsNothing);
    expect(find.byKey(const ValueKey('cpuThreads')), findsNothing);

    await open(tester, ComputeDevice.gpu);
    expect(find.textContaining('RTX 4070'), findsOneWidget);
    expect(find.byKey(const ValueKey('cpuThreads')), findsNothing);

    // Everything on the processor: how much of it to use is the question
    // left, and it is asked here rather than in a card of its own.
    await open(tester, ComputeDevice.cpu);
    expect(find.textContaining('RTX 4070'), findsNothing);
    expect(find.byKey(const ValueKey('cpuThreads')), findsOneWidget);
    expect(find.textContaining('Распознавание занимает'), findsOneWidget);
  });

  testWidgets('offers speech the card but never Vulkan', (tester) async {
    await pumpLoreDub(tester, const Size(1280, 900));
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();

    final speech = find.text('Озвучка');
    await tester.scrollUntilVisible(speech, 300, scrollable: settingsScroller());
    await tester.pumpAndSettle();

    // Silero rides on the worker's torch, which has no Vulkan build at all.
    // CUDA it would take; this machine simply has no card to give it.
    Finder cell(String backend) => find.byKey(ValueKey('backendCell-speech-$backend'));
    expect(
      find.descendant(
        of: cell('vulkan'),
        matching: find.byTooltip('Не поддерживается этой моделью'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: cell('cuda'),
        matching: find.byTooltip('Нет подходящей видеокарты или драйвера'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: cell('cpu'), matching: find.byTooltip('Стадия считается здесь')),
      findsOneWidget,
    );
  });

  group('the stage-by-device table', () {
    // The Vulkan whisper.cpp ships inside the installer rather than the
    // catalogue, so it is named here the way the storage service names it.
    const nvidia = ComputeAvailability(
      adapters: [
        GraphicsAdapter(name: 'NVIDIA GeForce RTX 3080 Ti', vendor: GraphicsVendor.nvidia),
      ],
      cudaDriver: true,
      vulkanLoader: true,
      installedRuntimes: {whisperCudaRuntimeId, 'whisper-vulkan'},
    );
    late _RecordingRuntimeRepository runtimes;

    Future<DashboardCubits> pumpTable(
      WidgetTester tester, {
      ComputeAvailability availability = nvidia,
    }) async {
      SharedPreferences.setMockInitialValues({});
      runtimes = _RecordingRuntimeRepository();
      final cubits = stage(
        buildCubits(runtimes: runtimes),
        section: DashboardSection.settings,
        availability: availability,
        runtimes: [
          RuntimeInstallState(package: runtimePackageById(whisperCudaRuntimeId)!, installed: true),
          RuntimeInstallState(package: runtimePackageById(torchCudaRuntimeId)!),
        ],
      );
      await pumpDashboard(tester, cubits, const Size(1280, 1000));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('runtimeTile-$torchCudaRuntimeId')),
        300,
        scrollable: settingsScroller(),
      );
      await tester.pumpAndSettle();
      return cubits;
    }

    Finder cell(String stage, String backend) =>
        find.byKey(ValueKey('backendCell-$stage-$backend'));

    testWidgets('marks the device each stage runs on', (tester) async {
      await pumpTable(tester);

      Color colour(Finder finder) => tester
          .widget<Material>(find.descendant(of: finder, matching: find.byType(Material)).first)
          .color!;
      // Automatic puts Whisper on the CUDA it has, and translation, still
      // without its package, on the processor.
      expect(colour(cell('recognition', 'cuda')), LoreDubPalette.graphite);
      expect(colour(cell('recognition', 'cpu')), LoreDubPalette.panel);
      expect(colour(cell('translation', 'cpu')), LoreDubPalette.graphite);
      expect(
        find.descendant(of: cell('translation', 'cuda'), matching: find.text('2.5 ГБ')),
        findsOneWidget,
        reason: 'the missing package names its size',
      );
    });

    testWidgets('picks a ready device by tapping its cell', (tester) async {
      final cubits = await pumpTable(tester);

      await tester.ensureVisible(cell('recognition', 'vulkan'));
      await tester.pumpAndSettle();
      await tester.tap(cell('recognition', 'vulkan'));
      await tester.pumpAndSettle();

      expect(cubits.settings.settings.recognitionBackend, ComputeBackend.vulkan);
    });

    testWidgets('fetches a missing package from its cell', (tester) async {
      await pumpTable(tester);

      await tester.ensureVisible(cell('translation', 'cuda'));
      await tester.pumpAndSettle();
      await tester.tap(cell('translation', 'cuda'));
      await tester.pumpAndSettle();

      expect(runtimes.installed, [torchCudaRuntimeId]);
    });

    // A copy built without the Vulkan SDK carries no Vulkan whisper, and
    // nothing in the catalogue would fetch one. The cell used to read as
    // ready and swallow the press that followed.
    testWidgets('says when a build this copy has not got is asked for', (tester) async {
      final cubits = await pumpTable(
        tester,
        availability: nvidia.copyWith(installedRuntimes: const {whisperCudaRuntimeId}),
      );

      await tester.ensureVisible(cell('recognition', 'vulkan'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: cell('recognition', 'vulkan'),
          matching: find.byTooltip(
            'Этой сборки нет в вашей копии: сборка Whisper с Vulkan входит в '
            'установщик, только если её удалось собрать',
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(cell('recognition', 'vulkan'));
      await tester.pumpAndSettle();
      expect(
        cubits.settings.settings.recognitionBackend,
        isNull,
        reason: 'a cell that cannot be chosen must not store a pin either',
      );
    });

    testWidgets('draws the packages as tiles with their buttons', (tester) async {
      await pumpTable(tester);

      Finder on(String id, String tooltip) => find.descendant(
        of: find.byKey(ValueKey('runtimeTile-$id')),
        matching: find.byTooltip(tooltip),
      );
      expect(on(whisperCudaRuntimeId, 'Удалить'), findsOneWidget);
      expect(on(torchCudaRuntimeId, 'Скачать'), findsOneWidget);
    });
  });

  testWidgets('remembers the compute preset the user pressed', (tester) async {
    await pumpLoreDub(tester, const Size(1280, 900));
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();

    final section = find.text('Вычислительное устройство');
    await tester.scrollUntilVisible(section, 300, scrollable: settingsScroller());
    await tester.pumpAndSettle();

    final preset = find.descendant(
      of: find.byType(SegmentedButton<ComputeDevice>),
      matching: find.text('CPU'),
    );
    await tester.tap(preset);
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('computeDevice'), 'cpu');
  });

  testWidgets('marks the live section with the audio capture drawing', (tester) async {
    // Material Icons has no audio_capture, so it is an SVG rather than a font
    // glyph; a missing asset would otherwise only show as a blank square.
    await pumpLoreDub(tester, const Size(1280, 900));

    final sidebar = find.byType(SvgPicture);
    expect(sidebar, findsOneWidget);
    expect(
      find.descendant(of: find.widgetWithText(InkWell, 'Эфир'), matching: sidebar),
      findsOneWidget,
    );
  });

  testWidgets('carries the same drawing into the compact navigation', (tester) async {
    await pumpLoreDub(tester, const Size(760, 720));

    expect(
      find.descendant(of: find.byType(NavigationBar), matching: find.byType(SvgPicture)),
      findsWidgets,
    );
  });

  testWidgets('says why a GPU runtime did not install instead of looking untouched', (
    tester,
  ) async {
    final cubits = stage(
      buildCubits(),
      section: DashboardSection.settings,
      availability: const ComputeAvailability(
        adapters: [
          GraphicsAdapter(name: 'NVIDIA GeForce RTX 3080 Ti', vendor: GraphicsVendor.nvidia),
        ],
        cudaDriver: true,
      ),
      runtimes: [
        RuntimeInstallState(package: runtimePackageById(whisperCudaRuntimeId)!),
        RuntimeInstallState(
          package: runtimePackageById(torchCudaRuntimeId)!,
          error: const LoreDubFailure(
            FailureCode.runtimeInstallFailed,
            detail: '1\nERROR: Could not install packages due to an OSError',
          ),
        ),
      ],
    );
    await pumpDashboard(tester, cubits, const Size(1280, 1000));

    final message = find.textContaining('Не удалось установить GPU-рантайм');
    await tester.scrollUntilVisible(message, 300, scrollable: settingsScroller());
    await tester.pumpAndSettle();

    expect(message, findsOneWidget);
    expect(find.textContaining('OSError'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('runtimeTile-$torchCudaRuntimeId')),
        matching: find.byTooltip('Скачать'),
      ),
      findsOneWidget,
      reason: 'the button stays, so the install can be tried again',
    );
  });

  group('removing a GPU runtime', () {
    /// Records what the interface asked for instead of touching the disk.
    /// Real file futures never complete inside a widget test's fake async
    /// zone, and what is under test here is the question, not the delete —
    /// the delete itself is covered in the runtime store's own tests.
    late _RecordingRuntimeRepository runtimes;

    /// The delete button of the CUDA Whisper tile.
    Finder removeButton() => find.descendant(
      of: find.byKey(const ValueKey('runtimeTile-$whisperCudaRuntimeId')),
      matching: find.byTooltip('Удалить'),
    );

    Future<void> stageInstalledRuntime(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      runtimes = _RecordingRuntimeRepository();
      final cubits = stage(
        buildCubits(runtimes: runtimes),
        section: DashboardSection.settings,
        availability: const ComputeAvailability(installedRuntimes: {whisperCudaRuntimeId}),
        runtimes: [
          RuntimeInstallState(
            package: runtimePackageById(whisperCudaRuntimeId)!,
            installed: true,
          ),
        ],
      );

      await pumpDashboard(tester, cubits, const Size(1280, 1000));
      await tester.scrollUntilVisible(
        removeButton(),
        300,
        scrollable: settingsScroller(),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('asks before giving hundreds of megabytes back', (tester) async {
      await stageInstalledRuntime(tester);

      await tester.tap(removeButton());
      await tester.pumpAndSettle();

      expect(find.text('Точно удалить?'), findsOneWidget);
      expect(find.text('Удалить полностью'), findsOneWidget);
      expect(find.text('Оставить'), findsOneWidget);
      expect(runtimes.removed, isEmpty, reason: 'asking must not act');
    });

    testWidgets('names the size that is about to be freed', (tester) async {
      await stageInstalledRuntime(tester);

      await tester.tap(removeButton());
      await tester.pumpAndSettle();

      expect(find.textContaining('436 МБ'), findsWidgets);
    });

    testWidgets('keeps the runtime when the question is declined', (tester) async {
      await stageInstalledRuntime(tester);

      await tester.tap(removeButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Оставить'));
      await tester.pumpAndSettle();

      expect(find.text('Точно удалить?'), findsNothing);
      expect(runtimes.removed, isEmpty);
      expect(removeButton(), findsOneWidget);
    });

    testWidgets('removes it once the question is answered', (tester) async {
      await stageInstalledRuntime(tester);

      await tester.tap(removeButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить полностью'));
      await tester.pumpAndSettle();

      expect(find.text('Точно удалить?'), findsNothing);
      expect(runtimes.removed, [whisperCudaRuntimeId]);
      expect(
        removeButton(),
        findsNothing,
        reason: 'the offer goes away with the runtime',
      );
    });
  });

  group('the version button', () {
    DashboardCubits withUpdates(UpdateState updates) => stage(buildCubits(), updates: updates);

    testWidgets('shows the version this build carries', (tester) async {
      final cubits = withUpdates(
        const UpdateState(status: UpdateStatus.current, currentVersion: '0.2.1'),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      expect(find.text('Версия 0.2.1'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_outward_rounded), findsNothing);
    });

    testWidgets('lines the version icon up with the status caption', (tester) async {
      final cubits = withUpdates(
        const UpdateState(status: UpdateStatus.current, currentVersion: '0.2.1'),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      final icon = tester.getTopLeft(find.byIcon(Icons.verified_outlined));
      final status = tester.getTopLeft(find.text('WINDOWS · LOCAL PROCESSING'));

      expect(
        (icon.dx - status.dx).abs(),
        lessThanOrEqualTo(0.5),
        reason: 'the foot of the panel reads down one left edge',
      );
      expect(tester.getTopLeft(find.text('Версия 0.2.1')).dx, greaterThan(icon.dx));
    });

    testWidgets('spins while the check is running', (tester) async {
      final cubits = withUpdates(
        const UpdateState(status: UpdateStatus.checking, currentVersion: '0.2.1'),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final button = tester.widget<TextButton>(
        find.ancestor(of: find.text('Версия 0.2.1'), matching: find.byType(TextButton)),
      );
      expect(button.onPressed, isNull, reason: 'no second check on top of the first');
    });

    final release = AppRelease(
      version: '0.3.0',
      page: Uri.parse('https://github.com/Hecatoncheir/LoreDub/releases/tag/v0.3.0'),
      installer: ReleaseInstaller(
        name: 'LoreDub-0.3.0-windows-x64-setup.exe',
        url: Uri.parse(
          'https://github.com/Hecatoncheir/LoreDub/releases/download/v0.3.0/setup.exe',
        ),
        size: 181234513,
      ),
    );

    testWidgets('puts the update where the version was once a newer one exists', (tester) async {
      final cubits = withUpdates(
        UpdateState(status: UpdateStatus.available, currentVersion: '0.2.1', release: release),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      expect(find.text('Текущая версия v0.2.1 → v0.3.0'), findsOneWidget);
      expect(find.text('Версия 0.2.1'), findsNothing, reason: 'the version steps aside');
      // This test build was not put in place by the setup, so it points at
      // the release page instead of installing over itself.
      expect(find.byTooltip('Открыть страницу версии 0.3.0'), findsOneWidget);
    });

    group('installing it', () {
      late _FakeUpdateRepository updates;

      DashboardCubits withInstaller(UpdateState state) {
        SharedPreferences.setMockInitialValues({});
        updates = _FakeUpdateRepository();
        final cubits = DashboardCubits(
          AppRepository(NativeEngineService(), SettingsService()),
          ModelRepository(ModelStorageService()),
          RuntimeRepository(RuntimeStorageService()),
          updates,
        );
        addTearDown(cubits.dispose);
        return stage(cubits, updates: state);
      }

      final available = UpdateState(
        status: UpdateStatus.available,
        currentVersion: '0.2.1',
        release: release,
        installable: true,
      );

      testWidgets('downloads the setup and then offers the restart', (tester) async {
        final cubits = withInstaller(available);
        await pumpDashboard(tester, cubits, const Size(1280, 900));

        expect(find.byTooltip('Нажмите, чтобы скачать и установить обновление'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('updateAvailable')));
        await tester.pumpAndSettle();

        expect(updates.downloaded, ['LoreDub-0.3.0-windows-x64-setup.exe']);
        expect(find.text('Текущая версия v0.2.1 → v0.3.0'), findsNothing);
        expect(find.text('Обновлено'), findsOneWidget);
        expect(find.text('Перезапустить'), findsOneWidget);
      });

      testWidgets('shows a bar and the share in place of the text while it downloads', (
        tester,
      ) async {
        final cubits = withInstaller(available.copyWith(installProgress: 0.42));
        await pumpDashboard(tester, cubits, const Size(1280, 900));

        expect(find.text('42%'), findsOneWidget);
        expect(find.text('Текущая версия v0.2.1 → v0.3.0'), findsNothing);
      });

      testWidgets('restarts into the downloaded setup', (tester) async {
        final cubits = withInstaller(
          available.copyWith(installerPath: r'C:\updates\LoreDub-0.3.0-windows-x64-setup.exe'),
        );
        await pumpDashboard(tester, cubits, const Size(1280, 900));

        await tester.tap(find.byKey(const ValueKey('updateRestart')));
        await tester.pumpAndSettle();

        expect(updates.restarted, [r'C:\updates\LoreDub-0.3.0-windows-x64-setup.exe']);
      });
    });

    testWidgets('says the check failed rather than claiming to be current', (tester) async {
      final cubits = withUpdates(
        const UpdateState(status: UpdateStatus.failed, currentVersion: '0.2.1'),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      expect(find.byTooltip('Не удалось проверить обновления'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('checks again when the version is tapped', (tester) async {
      final cubits = withUpdates(
        const UpdateState(status: UpdateStatus.current, currentVersion: '0.2.1'),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      await tester.tap(find.text('Версия 0.2.1'));
      await tester.pump();

      // The offline client the harness uses answers 503, so the check ends
      // in failure — what matters is that it ran.
      expect(cubits.shell.state.updates.status, isNot(UpdateStatus.current));
    });
  });

  group('stopping a download from the interface', () {
    Future<DashboardCubits> pumpDownloading(
      WidgetTester tester, {
      required bool paused,
    }) async {
      final whisper = modelCatalog.firstWhere((model) => model.kind == ModelKind.recognition);
      final cubits = stage(
        buildCubits(),
        section: DashboardSection.models,
        models: [
          for (final model in modelCatalog)
            ModelInstallState(
              model: model,
              progress: model.id == whisper.id ? 0.42 : null,
              paused: model.id == whisper.id && paused,
            ),
        ],
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));
      await tester.pumpAndSettle();
      return cubits;
    }

    testWidgets('offers pause and cancel while a download runs', (tester) async {
      await pumpDownloading(tester, paused: false);

      expect(find.byTooltip('Приостановить'), findsOneWidget);
      expect(find.byTooltip('Отменить'), findsOneWidget);
      expect(find.byTooltip('Продолжить'), findsNothing);
    });

    testWidgets('offers resume once it is paused', (tester) async {
      await pumpDownloading(tester, paused: true);

      expect(find.byTooltip('Продолжить'), findsOneWidget);
      expect(find.byTooltip('Приостановить'), findsNothing);
      expect(find.text('42%'), findsOneWidget, reason: 'the ring keeps where it stopped');
    });

    testWidgets('stopping what is not running changes nothing', (tester) async {
      final cubits = await pumpDownloading(tester, paused: false);

      // The staged state has no attempt in flight, so there is no control to
      // signal. Asking anyway must be harmless rather than throwing.
      cubits.downloads
        ..pauseDownload(whisperModelId)
        ..cancelDownload(whisperModelId);

      expect(cubits.downloads.state.isStopping(whisperModelId), isFalse);
    });

    testWidgets('a paused download is resumed from its own bar', (tester) async {
      await pumpDownloading(tester, paused: true);

      final bar = find.byKey(const ValueKey('whisperBar-$whisperModelId'));

      // The smallest bar spends its room on the ring; the pause shows as the
      // play button in place of the pause one.
      expect(find.descendant(of: bar, matching: find.text('42%')), findsOneWidget);
      expect(find.descendant(of: bar, matching: find.byTooltip('Продолжить')), findsOneWidget);
      expect(find.descendant(of: bar, matching: find.byTooltip('Отменить')), findsOneWidget);
      expect(
        find.descendant(of: bar, matching: find.byTooltip('Скачать')),
        findsNothing,
        reason: 'resuming is the download button of a paused bar',
      );
    });

    testWidgets('fills the bar of a download from the bottom', (tester) async {
      await pumpDownloading(tester, paused: false);

      final fill = tester.widget<AnimatedFractionallySizedBox>(
        find.descendant(
          of: find.byKey(const ValueKey('whisperBar-$whisperModelId')),
          matching: find.byType(AnimatedFractionallySizedBox),
        ),
      );
      expect(fill.heightFactor, 0.42);
      // The figure sits inside the ring, even on the smallest bar.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('whisperDial-$whisperModelId')),
          matching: find.text('42%'),
        ),
        findsOneWidget,
      );
    });
  });

  group('choosing a recognition model', () {
    Future<DashboardCubits> pumpModels(
      WidgetTester tester, {
      AppSettings settings = const AppSettings(),
    }) async {
      final cubits = stage(
        buildCubits(),
        section: DashboardSection.models,
        settings: settings,
        models: catalogue(),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 1000));
      await tester.pumpAndSettle();
      return cubits;
    }

    testWidgets('lists every whisper build and marks the default', (tester) async {
      final cubits = await pumpModels(tester);

      expect(find.text('base'), findsOneWidget);
      expect(find.text('small'), findsOneWidget);
      expect(find.text('large-v3-turbo'), findsOneWidget);
      expect(
        cubits.selection.recognition?.model.id,
        whisperModelId,
        reason: 'an unset choice falls back to the smallest',
      );
      // The build in use is the dark bar; the others stay light.
      Color barColour(String id) => tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byKey(ValueKey('whisperBar-$id')),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color!;
      expect(barColour(whisperModelId), LoreDubPalette.graphite);
      expect(barColour('whisper-small'), LoreDubPalette.panel);
    });

    testWidgets('draws every bar to the size of its download', (tester) async {
      await pumpModels(tester);

      double height(String id) => tester.getSize(find.byKey(ValueKey('whisperBar-$id'))).height;
      final small = modelCatalog.firstWhere((model) => model.id == 'whisper-small');
      final turbo = modelCatalog.firstWhere((model) => model.id == 'whisper-large-v3-turbo-q5');

      expect(
        height('whisper-large-v3-turbo-q5') / height('whisper-small'),
        closeTo(turbo.downloadBytes / small.downloadBytes, 0.01),
      );
      expect(height(whisperModelId), lessThan(height('whisper-small')));
      expect(find.text('465 МБ'), findsOneWidget, reason: 'each size is written on the axis');
      expect(find.text('хорошо'), findsOneWidget);
      expect(find.text('без перевода'), findsOneWidget, reason: 'turbo only transcribes');
    });

    testWidgets('keeps a button on every bar for what can be done with it', (tester) async {
      final cubits = stage(
        buildCubits(),
        section: DashboardSection.models,
        models: [
          for (final state in catalogue())
            state.model.id == 'whisper-small' ? ModelInstallState(model: state.model) : state,
        ],
      );
      await pumpDashboard(tester, cubits, const Size(1280, 1000));
      await tester.pumpAndSettle();

      Finder on(String id, String tooltip) => find.descendant(
        of: find.byKey(ValueKey('whisperBar-$id')),
        matching: find.byTooltip(tooltip),
      );
      expect(on('whisper-small', 'Скачать'), findsOneWidget);
      expect(on(whisperModelId, 'Удалить'), findsOneWidget);
      expect(on('whisper-large-v3-turbo-q5', 'Удалить'), findsOneWidget);
    });

    testWidgets('asks before deleting a downloaded model', (tester) async {
      final cubits = await pumpModels(tester);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('whisperBar-whisper-small')),
          matching: find.byTooltip('Удалить'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Удалить модель?'), findsOneWidget);
      expect(find.textContaining('Whisper small (465 МБ)'), findsOneWidget);

      await tester.tap(find.text('Оставить'));
      await tester.pumpAndSettle();

      expect(find.text('Удалить модель?'), findsNothing);
      expect(
        cubits.downloads.state.models
            .firstWhere((state) => state.model.id == 'whisper-small')
            .installed,
        isTrue,
      );
    });

    testWidgets('keeps the model in use while dubbing runs', (tester) async {
      final cubits = stage(
        buildCubits(),
        section: DashboardSection.models,
        models: catalogue(),
        status: PipelineStatus.listening,
      );
      await pumpDashboard(tester, cubits, const Size(1280, 1000));
      await tester.pumpAndSettle();

      final locked = find.descendant(
        of: find.byKey(const ValueKey('whisperBar-$whisperModelId')),
        matching: find.byTooltip('Выбранную модель нельзя удалить, пока идёт озвучка'),
      );
      expect(locked, findsOneWidget);
      expect(
        tester
            // The button builds its tooltip inside itself.
            .widget<IconButton>(find.ancestor(of: locked, matching: find.byType(IconButton)))
            .onPressed,
        isNull,
      );
    });

    testWidgets('grows a bar a little under the pointer', (tester) async {
      await pumpModels(tester);
      final bar = find.byKey(const ValueKey('whisperBar-whisper-small'));
      double scale() => tester
          .widget<AnimatedScale>(find.descendant(of: bar, matching: find.byType(AnimatedScale)))
          .scale;
      expect(scale(), 1);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(bar));
      await tester.pumpAndSettle();

      expect(scale(), greaterThan(1));
      expect(scale(), lessThan(1.1), reason: 'a little, not a zoom');
    });

    testWidgets('remembers the model tapped in the list', (tester) async {
      final cubits = await pumpModels(tester);

      await tester.tap(find.text('small'));
      await tester.pumpAndSettle();

      expect(cubits.selection.recognition?.model.id, 'whisper-small');
      expect((await SettingsService().load()).whisperModel, 'whisper-small');
    });

    testWidgets('falls back when the stored choice names a model that is gone', (tester) async {
      final cubits = await pumpModels(
        tester,
        settings: const AppSettings(whisperModel: 'whisper-from-an-older-build'),
      );

      expect(cubits.selection.recognition?.model.id, whisperModelId);
    });

    testWidgets('asks turbo to transcribe rather than translate', (tester) async {
      final cubits = await pumpModels(
        tester,
        settings: const AppSettings(whisperModel: 'whisper-large-v3-turbo-q5'),
      );

      expect(cubits.selection.recognitionTranslatesSpeech, isFalse);
      // Auto-detection is on by default, so nothing is claimed about the
      // original yet and no warning is due.
      expect(cubits.selection.recognitionNeedsEnglish, isFalse);
    });

    testWidgets('warns when a transcribe-only model meets a named foreign original', (
      tester,
    ) async {
      final cubits = await pumpModels(
        tester,
        settings: const AppSettings(
          whisperModel: 'whisper-large-v3-turbo-q5',
          detectSourceLanguage: false,
          sourceLanguage: 'de',
        ),
      );

      expect(cubits.selection.recognitionNeedsEnglish, isTrue);
      expect(find.textContaining('не переводит речь'), findsWidgets);
    });

    testWidgets('says nothing when that model is pointed at English', (tester) async {
      final cubits = await pumpModels(
        tester,
        settings: const AppSettings(
          whisperModel: 'whisper-large-v3-turbo-q5',
          detectSourceLanguage: false,
          sourceLanguage: 'en',
        ),
      );

      expect(cubits.selection.recognitionNeedsEnglish, isFalse);
    });
  });

  group('the dubbing voice', () {
    /// A dashboard with every model in place, sitting on the settings screen.
    /// The bootstrap's own load never finishes inside a widget test, so the
    /// state the card reads is put there directly.
    Future<DashboardCubits> pumpSettings(
      WidgetTester tester, {
      AppSettings settings = const AppSettings(),
      List<ModelInstallState>? models,
    }) async {
      final cubits = stage(
        buildCubits(),
        section: DashboardSection.settings,
        settings: settings,
        models: models ?? catalogue(),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 1000));
      await tester.scrollUntilVisible(
        find.text('Голос озвучки'),
        300,
        scrollable: settingsScroller(),
      );
      await tester.pumpAndSettle();
      return cubits;
    }

    testWidgets('offers automatic and a hand-picked voice', (tester) async {
      await pumpSettings(tester);

      expect(find.text('Голос озвучки'), findsOneWidget);
      expect(find.text('Выбрать'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('voice')),
        findsNothing,
        reason: 'automatic is the default, so there is nothing to pick from',
      );
    });

    testWidgets('lists the voices of the language once one is chosen by hand', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Выбрать'));
      await tester.pumpAndSettle();

      final picker = find.byKey(const ValueKey('voice'));
      expect(picker, findsOneWidget);
      final field = tester.widget<DropdownButtonFormField<String>>(picker);
      expect(field.initialValue, 'xenia', reason: 'the catalogue default for Russian');

      field.onChanged!('eugene');
      await tester.pumpAndSettle();

      final saved = await SettingsService().load();
      expect(saved.automaticVoice, isFalse);
      expect(saved.voice, 'eugene');
    });

    testWidgets('names the gender beside every voice', (tester) async {
      await pumpSettings(tester, settings: const AppSettings(automaticVoice: false));

      await tester.tap(find.byKey(const ValueKey('voice')));
      await tester.pumpAndSettle();

      expect(find.text('Aidar (мужской)'), findsWidgets);
      expect(find.text('Xenia (женский)'), findsWidgets);
    });

    testWidgets('says why a one-gender language cannot follow either', (tester) async {
      // Every Spanish voice is a man's.
      final cubits = await pumpSettings(
        tester,
        settings: const AppSettings(targetLanguage: 'es'),
      );

      expect(cubits.selection.canFollowSpeaker, isFalse);
      expect(find.textContaining('одного пола'), findsOneWidget);
    });

    testWidgets('re-voices in the original timbre once asked', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Голос оригинала'));
      await tester.pumpAndSettle();

      expect((await SettingsService().load()).originalVoice, isTrue);
      expect(find.textContaining('Тембр оригинала накладывается'), findsOneWidget);
      expect(
        find.textContaining('получает свой голос Silero'),
        findsOneWidget,
        reason: 'the characters are remembered from the start',
      );
    });

    testWidgets('offers to remember the characters without the original voice', (tester) async {
      // Automatic voice with the converter downloaded: it is what hears who
      // is speaking, so each character can be given a voice of their own.
      await pumpSettings(tester);

      expect(find.text('Запоминать голоса персонажей'), findsOneWidget);

      // The label is not the control; the switch beside it is.
      final remember = find.descendant(
        of: find
            .ancestor(
              of: find.text('Запоминать голоса персонажей'),
              matching: find.byType(Row),
            )
            .first,
        matching: find.byType(Switch),
      );
      await tester.ensureVisible(remember);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(remember).value, isTrue, reason: 'on from the start');
      expect(find.textContaining('получает свой голос Silero'), findsOneWidget);
    });

    testWidgets('asks for the converter before re-voicing', (tester) async {
      final cubits = await pumpSettings(
        tester,
        settings: const AppSettings(originalVoice: true),
        models: [
          for (final state in catalogue())
            state.model.kind == ModelKind.voiceConversion
                ? ModelInstallState(model: state.model)
                : state,
        ],
      );

      expect(find.textContaining('Нужен конвертер голоса'), findsOneWidget);
      expect(
        cubits.selection.requiredModelsInstalled,
        isFalse,
        reason: 'the start button waits for the download',
      );
    });

    testWidgets('offers overlapping characters only when voices can differ', (tester) async {
      await pumpSettings(tester);

      expect(find.text('Накладывать реплики разных персонажей'), findsOneWidget);
      final row = find.ancestor(
        of: find.text('Накладывать реплики разных персонажей'),
        matching: find.byType(Row),
      );
      await tester.tap(find.descendant(of: row.first, matching: find.byType(Switch)));
      await tester.pumpAndSettle();

      // Off to begin with, so the press is what turns overlapping on.
      expect((await SettingsService().load()).overlapVoices, isTrue);
    });

    testWidgets('hides overlapping when one voice reads every line', (tester) async {
      await pumpSettings(tester, settings: const AppSettings(automaticVoice: false));

      expect(find.text('Накладывать реплики разных персонажей'), findsNothing);
    });

    Finder clearButton() => find.ancestor(
      of: find.text('Очистить'),
      matching: find.byWidgetPredicate((widget) => widget is TextButton),
    );

    testWidgets('remembers the characters until told otherwise', (tester) async {
      await pumpSettings(tester, settings: const AppSettings(originalVoice: true));

      expect(find.text('Сохранённых голосов нет'), findsOneWidget);
      expect(
        tester.widget<TextButton>(clearButton()).onPressed,
        isNull,
        reason: 'there is nothing to clear',
      );
      expect(find.textContaining('У каждой игры свой банк'), findsOneWidget);

      final row = find.ancestor(
        of: find.text('Запоминать голоса персонажей'),
        matching: find.byType(Row),
      );
      await tester.tap(find.descendant(of: row.first, matching: find.byType(Switch)));
      await tester.pumpAndSettle();

      expect((await SettingsService().load()).voiceBank, isFalse);
      expect(find.textContaining('Персонажи не запоминаются'), findsOneWidget);
    });

    testWidgets('asks before clearing the kept voices', (tester) async {
      final cubits = await pumpSettings(tester, settings: const AppSettings(originalVoice: true));
      cubits.settings.seed(
        const SettingsState(
          settings: AppSettings(originalVoice: true, voiceBank: true),
          voiceBankSize: 3,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Сохранено 3 голоса'), findsOneWidget);
      await tester.tap(clearButton());
      await tester.pumpAndSettle();
      expect(find.text('Очистить банк голосов?'), findsOneWidget);

      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();

      expect(find.text('Очистить банк голосов?'), findsNothing);
      expect(cubits.settings.state.voiceBankSize, 3, reason: 'a cancel keeps every voice');
    });

    testWidgets('leaves OpenVoice out of the devices without the original voice', (tester) async {
      await pumpSettings(tester);
      await tester.scrollUntilVisible(
        find.textContaining('Silero держится'),
        300,
        scrollable: settingsScroller(),
      );

      expect(find.text('OpenVoice'), findsNothing);
    });

    testWidgets('gives OpenVoice a device of its own with the original voice', (tester) async {
      await pumpSettings(tester, settings: const AppSettings(originalVoice: true));
      await tester.scrollUntilVisible(
        find.text('OpenVoice'),
        300,
        scrollable: settingsScroller(),
      );
      expect(find.text('OpenVoice'), findsOneWidget);
    });
  });

  group('pausing a session', () {
    testWidgets('offers a pause beside a full stop, then a resume', (tester) async {
      final cubits = stage(buildCubits(), models: catalogue(), status: PipelineStatus.listening);
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      expect(find.byKey(const ValueKey('pauseButton')), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Остановить'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('pauseButton')));
      await tester.pumpAndSettle();

      expect(cubits.pipeline.state.status, PipelineStatus.paused);
      expect(find.text('Пауза'), findsOneWidget, reason: 'the status says so');
      expect(find.byKey(const ValueKey('stopButton')), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Продолжить'));
      await tester.pumpAndSettle();

      expect(cubits.pipeline.state.status, PipelineStatus.listening);
    });
  });

  group('the hotkeys', () {
    Future<DashboardCubits> pumpHotkeys(WidgetTester tester) async {
      final cubits = stage(
        buildCubits(),
        section: DashboardSection.settings,
        settings: const AppSettings(),
        models: catalogue(),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 1000));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('snapshotHotkey')),
        300,
        scrollable: settingsScroller(),
      );
      await tester.pumpAndSettle();
      return cubits;
    }

    Finder field(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(OutlinedButton),
    );

    Future<void> press(WidgetTester tester, List<LogicalKeyboardKey> keys) async {
      for (final key in keys) {
        await tester.sendKeyDownEvent(key);
      }
      for (final key in keys.reversed) {
        await tester.sendKeyUpEvent(key);
      }
      await tester.pumpAndSettle();
    }

    testWidgets('comes with a combination for each action', (tester) async {
      await pumpHotkeys(tester);

      expect(find.text('Горячие клавиши'), findsOneWidget);
      expect(find.text('Ctrl + Alt + P'), findsOneWidget);
      expect(find.text('Ctrl + Alt + R'), findsOneWidget);
      expect(find.text('Ctrl + Alt + S'), findsOneWidget);
    });

    testWidgets('refuses for selection the combination pausing has', (tester) async {
      await pumpHotkeys(tester);

      await tester.ensureVisible(field('snapshotHotkey'));
      await tester.pumpAndSettle();
      await tester.tap(field('snapshotHotkey'));
      await tester.pump();
      await press(tester, [
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.keyP,
      ]);

      expect(find.text('Это сочетание уже назначено на «Пауза»'), findsOneWidget);
      expect((await SettingsService().load()).snapshotHotkey, Hotkey.defaultSnapshot);
    });

    testWidgets('records the combination pressed on the field', (tester) async {
      await pumpHotkeys(tester);

      await tester.ensureVisible(field('pauseHotkey'));
      await tester.pumpAndSettle();
      await tester.tap(field('pauseHotkey'));
      await tester.pump();
      expect(find.text('Нажмите сочетание… (Esc — отмена)'), findsOneWidget);

      await press(tester, [
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.f9,
      ]);

      expect(find.text('Ctrl + Shift + F9'), findsOneWidget);
      expect((await SettingsService().load()).pauseHotkey?.display, 'Ctrl + Shift + F9');
    });

    testWidgets('refuses a bare letter, which would leave the game', (tester) async {
      await pumpHotkeys(tester);

      await tester.ensureVisible(field('pauseHotkey'));
      await tester.pumpAndSettle();
      await tester.tap(field('pauseHotkey'));
      await tester.pump();
      await press(tester, [LogicalKeyboardKey.keyK]);

      expect(find.textContaining('Добавьте Ctrl, Alt или Win'), findsOneWidget);
      expect((await SettingsService().load()).pauseHotkey, Hotkey.defaultPause);
    });

    testWidgets('refuses the combination the other action has', (tester) async {
      await pumpHotkeys(tester);

      await tester.ensureVisible(field('pauseHotkey'));
      await tester.pumpAndSettle();
      await tester.tap(field('pauseHotkey'));
      await tester.pump();
      await press(tester, [
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.keyR,
      ]);

      expect(find.text('Это сочетание уже назначено на «Восстановление»'), findsOneWidget);
    });

    testWidgets('lets a combination be removed', (tester) async {
      await pumpHotkeys(tester);

      final clear = find.descendant(
        of: find.byKey(const ValueKey('pauseHotkey')),
        matching: find.byTooltip('Убрать сочетание'),
      );
      await tester.ensureVisible(clear);
      await tester.pumpAndSettle();
      await tester.tap(clear);
      await tester.pumpAndSettle();

      expect(find.text('Не назначено'), findsOneWidget);
      expect((await SettingsService().load()).pauseHotkey, isNull);
    });
  });

  testWidgets('offers the text language on the page that reads the screen', (tester) async {
    final cubits = stage(
      buildCubits(),
      section: DashboardSection.snapshot,
      settings: const AppSettings(sourceLanguage: 'ru'),
      models: catalogue(),
    );
    await pumpDashboard(tester, cubits, const Size(1280, 900));

    expect(find.text('Язык текста'), findsOneWidget);
    expect(find.text('Определять язык'), findsNothing);
    expect(find.text('Текст на языке озвучки озвучивается без перевода'), findsOneWidget);
  });

  group('the snapshot screen', () {
    const snippet = TranscriptEntry(
      original: 'Press E to open',
      english: 'Press E to open',
      translated: 'Нажмите E, чтобы открыть',
      latency: Duration(milliseconds: 800),
    );

    FilledButton startButton(WidgetTester tester) =>
        tester.widget<FilledButton>(find.byKey(const ValueKey('snapshotStart')));

    const game = GameProcess(pid: 4242, name: 'game.exe', path: 'game.exe');

    DashboardCubits stageSnapshot({
      AppSettings settings = const AppSettings(),
      List<ModelInstallState>? models,
      LivePipelineState pipeline = const LivePipelineState(),
    }) {
      final cubits = stage(
        buildCubits(),
        section: DashboardSection.snapshot,
        settings: settings,
        models: models ?? catalogue(),
      );
      // The frame is read out of one window, so this session waits for a
      // game as live dubbing does.
      cubits.pipeline.seed(
        pipeline.copyWith(processes: const [game], selectedProcess: game),
      );
      return cubits;
    }

    testWidgets('reads the frame and the selection on one page', (tester) async {
      await pumpDashboard(tester, stageSnapshot(), const Size(1400, 1000));

      expect(find.text('02  /  ТЕКСТ С ЭКРАНА'), findsOneWidget);
      expect(find.text('Экран'), findsOneWidget);
      expect(find.text('Перевод с экрана'), findsOneWidget);
      expect(find.textContaining('Удерживайте Ctrl + Alt + S'), findsOneWidget);
      expect(find.textContaining('субтитры в рамке читаются'), findsOneWidget);
      expect(find.text('Язык текста'), findsOneWidget);
      expect(find.text('СУБТИТРЫ'), findsOneWidget);
      expect(find.text('Выделенные фрагменты появятся здесь'), findsOneWidget);
      expect(startButton(tester).onPressed, isNotNull);
      // The frame is drawn here before the game starts, and over the game
      // itself once it has.
      expect(find.byKey(const ValueKey('ocrRegion')), findsOneWidget);
      expect(find.textContaining('удерживайте Ctrl + Alt + F'), findsOneWidget);
    });

    testWidgets('says when a frame drawn over the game missed its window', (tester) async {
      final cubits = stageSnapshot(
        pipeline: const LivePipelineState(
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
      cubits.pipeline.seed(const LivePipelineState());
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

    testWidgets('stacks the language and its note where the card is narrow', (tester) async {
      // Wide enough for the frame to stand beside the controls, and so
      // narrow for the controls that the language and its note no longer
      // share a line: fixed at both halves, the row used to overflow.
      await pumpDashboard(tester, stageSnapshot(), const Size(1160, 1000));

      final field = find.byKey(const ValueKey('textLanguage-en'));
      final note = find.text('Текст на языке озвучки озвучивается без перевода');
      expect(field, findsOneWidget);
      expect(
        tester.getTopLeft(note).dy,
        greaterThan(tester.getBottomLeft(field).dy - 1),
        reason: 'the note went under the field rather than off the card',
      );
    });

    testWidgets('waits for the game whose window it reads', (tester) async {
      final cubits = stageSnapshot();
      cubits.pipeline.seed(const LivePipelineState());
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
        settings: const AppSettings().copyWith(clearSnapshotHotkey: true),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      expect(find.text('Клавиша выделения не назначена.'), findsOneWidget);
      expect(startButton(tester).onPressed, isNull);
    });

    testWidgets('shows what was selected while the session waits', (tester) async {
      final cubits = stageSnapshot(
        pipeline: const LivePipelineState(
          status: PipelineStatus.listening,
          session: PipelineSession.screen,
          snapshots: [snippet],
        ),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      expect(find.text('Нажмите E, чтобы открыть'), findsOneWidget);
      expect(find.text('Читаю экран'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Остановить'), findsOneWidget);
    });

    testWidgets('says when the selection held no text', (tester) async {
      final cubits = stageSnapshot(
        pipeline: const LivePipelineState(
          status: PipelineStatus.listening,
          session: PipelineSession.screen,
          snapshotMissed: true,
        ),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      expect(find.text('В выделенной области текст не найден'), findsOneWidget);
    });

    testWidgets('leaves the key to live dubbing while it runs', (tester) async {
      final cubits = stageSnapshot(
        pipeline: const LivePipelineState(status: PipelineStatus.listening),
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
      cubits.pipeline.seed(
        const LivePipelineState(
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

  group('the characters screen', () {
    const guard = Character(
      id: 'a1',
      name: 'Стражник',
      vector: [0.2, 0.4],
      gender: 'male',
      seconds: 2.5,
    );

    DashboardCubits stageCast({
      CharactersState characters = const CharactersState(loading: false),
      AppSettings settings = const AppSettings(),
    }) {
      final cubits = stage(
        buildCubits(),
        section: DashboardSection.characters,
        settings: settings,
        models: catalogue(),
      );
      cubits.characters.seed(characters);
      return cubits;
    }

    testWidgets('sits before Settings and says how a voice is recorded', (tester) async {
      await pumpDashboard(tester, stageCast(), const Size(1280, 900));

      expect(find.text('03  /  СОСТАВ ПЕРСОНАЖЕЙ'), findsOneWidget);
      expect(find.text('Голоса персонажей'), findsOneWidget);
      expect(find.textContaining('Пока ни одного персонажа'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Запустить запись'), findsOneWidget);
    });

    testWidgets('keeps a full card inside its tile', (tester) async {
      // Name, what was recorded, whose voice reads it, and the packs it is
      // in — all at once, in a window narrow enough for the lines to wrap.
      await pumpDashboard(
        tester,
        stageCast(
          characters: const CharactersState(
            loading: false,
            characters: [
              Character(
                id: 'a1',
                name: 'Скарн',
                vector: [0.2, 0.4],
                gender: 'male',
                seconds: 6,
                voicedBy: 'b2',
              ),
              Character(id: 'b2', name: 'Кайра', vector: [0.3], gender: 'female', seconds: 4.8),
            ],
            packs: [
              CharacterPack(id: 'p1', name: 'Старый порт', characterIds: ['a1', 'b2']),
            ],
          ),
        ),
        const Size(1000, 900),
      );

      expect(tester.takeException(), isNull, reason: 'the tile holds its own content');
    });

    testWidgets('holds it at the narrowest window the app opens in', (tester) async {
      await pumpDashboard(
        tester,
        stageCast(
          characters: const CharactersState(
            loading: false,
            characters: [
              Character(
                id: 'a1',
                name: 'Персонаж с очень длинным именем',
                vector: [0.2, 0.4],
                gender: 'female',
                seconds: 12,
                voicedBy: 'b2',
              ),
              Character(id: 'b2', name: 'Кузнец', vector: [0.3], gender: 'male', seconds: 4),
            ],
            packs: [
              CharacterPack(id: 'p1', name: 'Таверна', characterIds: ['a1']),
              CharacterPack(id: 'p2', name: 'Рынок', characterIds: ['a1']),
            ],
          ),
        ),
        const Size(960, 640),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('shows what a card holds and waits for the session', (tester) async {
      await pumpDashboard(
        tester,
        stageCast(characters: const CharactersState(loading: false, characters: [guard])),
        const Size(1280, 900),
      );

      expect(find.text('Стражник'), findsOneWidget);
      expect(find.textContaining('Голос записан'), findsOneWidget);
      expect(
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.mic_rounded)).onPressed,
        isNull,
        reason: 'nothing is listening yet',
      );
    });

    testWidgets('records into a card once the session runs', (tester) async {
      final cubits = stageCast(
        characters: const CharactersState(
          loading: false,
          status: PipelineStatus.listening,
          characters: [guard],
        ),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      final record = find.widgetWithIcon(IconButton, Icons.mic_rounded);
      expect(tester.widget<IconButton>(record).onPressed, isNotNull);

      await tester.tap(record);
      await tester.pumpAndSettle();

      expect(cubits.characters.state.recordingId, 'a1');
      // The take runs until it is stopped, so the card counts it rather than
      // saying only that something is going on.
      expect(find.textContaining('Записано'), findsOneWidget);

      // A take runs until it is stopped, so the test stops it — as the
      // player would, by the button that is now a square.
      await tester.tap(find.widgetWithIcon(IconButton, Icons.stop_rounded));
      await tester.pumpAndSettle();

      expect(cubits.characters.state.recordingId, isNull);
    });

    testWidgets('makes a pack and says a card can be dropped into it', (tester) async {
      final cubits = stageCast(
        characters: const CharactersState(loading: false, characters: [guard]),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      expect(find.textContaining('Пакетов пока нет'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('packsAdd')));
      await tester.pumpAndSettle();

      expect(cubits.characters.state.packs.single.name, 'Новый пакет');
      expect(find.textContaining('Перетащите сюда'), findsOneWidget);
    });

    testWidgets('says who reads a card, and leaves the setting to the graph', (tester) async {
      final cubits = stageCast(
        characters: const CharactersState(
          loading: false,
          characters: [
            Character(id: 'a1', name: 'Стражник', vector: [0.2], voicedBy: 'b2'),
            Character(id: 'b2', name: 'Кузнец', vector: [0.3]),
          ],
        ),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      expect(find.text('Звучит как «Кузнец»'), findsOneWidget);
      // One scheme decides who speaks for whom. The card says what it is;
      // the graph is where it is drawn.
      expect(find.byKey(const ValueKey('voiceAs-a1')), findsNothing);
      expect(find.byIcon(Icons.published_with_changes_rounded), findsNothing);
    });

    testWidgets('turns the play button into a stop while a clip sounds', (tester) async {
      final cubits = stageCast(
        characters: const CharactersState(
          loading: false,
          characters: [guard],
          clips: {'a1'},
          playingId: 'a1',
        ),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      // A recording may run for three minutes, so the button that started it
      // is the one that ends it.
      expect(find.byTooltip('Остановить воспроизведение'), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.descendant(
                of: find.byKey(const ValueKey('playClip-a1')),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNotNull,
        reason: 'the same button ends it',
      );
    });

    testWidgets('says on the button when a sample carries no timbre', (tester) async {
      // Without Original voice the dubbing reads every card in a plain
      // synthesized voice, and a sample that sounds like nobody in
      // particular is exactly right — so the button says why beforehand.
      final plain = stageCast(
        characters: const CharactersState(loading: false, characters: [guard]),
      );
      await pumpDashboard(tester, plain, const Size(1280, 900));

      expect(find.byTooltip('Послушать голос озвучки'), findsNothing);
      expect(
        find.byTooltip(
          'Послушать голос озвучки. Тембр персонажа не переносится: включите «Голос оригинала» '
          'на экране «Модели», иначе персонажа читает обычный голос синтеза',
        ),
        findsOneWidget,
      );

      final cloning = stageCast(
        characters: const CharactersState(loading: false, characters: [guard]),
        settings: const AppSettings(originalVoice: true),
      );
      await pumpDashboard(tester, cloning, const Size(1280, 900));

      expect(find.byTooltip('Послушать голос озвучки'), findsOneWidget);
    });

    testWidgets('puts the packs beside the cast, and under it in a narrow window', (
      tester,
    ) async {
      final cubits = stageCast(
        characters: const CharactersState(
          loading: false,
          characters: [guard],
          packs: [CharacterPack(id: 'p1', name: 'Таверна')],
        ),
      );
      await pumpDashboard(tester, cubits, const Size(1400, 900));

      final cast = tester.getRect(find.byType(CharacterTile));
      final packs = tester.getRect(find.byType(CharacterPackArea));
      expect(
        packs.left,
        greaterThan(cast.right),
        reason: 'a card is carried across to the pack rather than down a scroll',
      );
      expect(
        (packs.top - cast.top).abs(),
        lessThan(200),
        reason: 'and both ends of the journey are in sight at once',
      );

      // A window too narrow for two columns puts them back one under the
      // other, where the drag is longer but possible.
      await pumpDashboard(tester, cubits, const Size(840, 900));

      expect(
        tester.getRect(find.byType(CharacterPackArea)).top,
        greaterThan(tester.getRect(find.byType(CharacterTile)).top),
      );
    });

    testWidgets('drops a card into a pack and takes it back out', (tester) async {
      final cubits = stageCast(
        characters: const CharactersState(
          loading: false,
          characters: [guard],
          packs: [CharacterPack(id: 'p1', name: 'Таверна')],
        ),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      final card = find.byType(CharacterTile);
      final pack = find.byType(CharacterPackArea);
      final distance = tester.getCenter(pack) - tester.getCenter(card);
      await tester.timedDrag(card, distance, const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(cubits.characters.state.packs.single.characterIds, ['a1']);
      expect(
        cubits.characters.state.characters.single.name,
        'Стражник',
        reason: 'dropped into the pack, not moved out of the cast',
      );

      // The cross on the card inside the pack takes it out again.
      await tester.tap(find.byTooltip('Убрать из пакета'));
      await tester.pumpAndSettle();

      expect(cubits.characters.state.packs.single.characterIds, isEmpty);
    });

    testWidgets('keeps saving and throwing away a card behind its menu', (tester) async {
      final cubits = stageCast(
        characters: const CharactersState(loading: false, characters: [guard]),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      // Neither of the two is a further unlabelled icon beside the
      // microphone, where delete sat a slip away from record.
      expect(find.text('Удалить персонажа'), findsNothing);

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Сохранить карточку в файл'), findsOneWidget);

      await tester.tap(find.text('Удалить персонажа'));
      await tester.pumpAndSettle();
      expect(find.text('Удалить персонажа?'), findsOneWidget);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(cubits.characters.state.characters, hasLength(1));
    });
  });

  testWidgets('takes only sound out of what is dropped on a card', (tester) async {
    // Windows decodes what it can play, so a card takes the game's own
    // ogg and an mp3 beside it; a folder or a screenshot dropped by
    // mistake is left where it was.
    expect(
      CharacterTile.soundAmong(const [
        r'C:\game\vo\guard_01.OGG',
        r'C:\music\theme.mp3',
        r'C:\shots\screen.png',
        r'C:\game\vo',
      ]),
      [
        r'C:\game\vo\guard_01.OGG',
        r'C:\music\theme.mp3',
      ],
    );
  });

  group('the voices of the scene', () {
    const guard = Character(id: 'a1', name: 'Стражник', vector: [0.2, 0.4]);

    DashboardCubits stageScene({
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
      cubits.characters.seed(CharactersState(loading: false, characters: characters));
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
      cubits.characters.seed(const CharactersState(loading: false));
      await pumpDashboard(tester, cubits, const Size(1400, 900));

      expect(
        tester.widget<TextButton>(find.byKey(const ValueKey('sceneListen'))).onPressed,
        isNull,
      );
      expect(find.textContaining('Голоса различаются конвертером'), findsOneWidget);
    });

    testWidgets('says it is listening while the voices are placed', (tester) async {
      final cubits = stageScene();
      cubits.pipeline.seed(
        const LivePipelineState(
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
          ..pipeline.seed(
            const LivePipelineState(
              status: PipelineStatus.listening,
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
  testWidgets('keeps a scheme under the name the dialog is given', (tester) async {
    // Through the running application rather than staged cubits: what broke
    // here was the dialog's own field being let go of while the dialog was
    // still fading, and a fade needs a screen that really has one.
    await pumpLoreDub(tester, const Size(1400, 920));
    await tester.tap(find.text('Схема'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byIcon(Icons.bookmark_add_outlined));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Название схемы'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Вечер в таверне');
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить схему'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull, reason: 'the dialog took nothing down with it');
    // The shelf keeps it, folded away until its heading is pressed.
    expect(find.textContaining('СОХРАНЁННЫЕ СХЕМЫ'), findsOneWidget);
    await tester.tap(find.textContaining('СОХРАНЁННЫЕ СХЕМЫ'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Вечер в таверне'), findsOneWidget);
  });

  group('the pipeline graph', () {
    const guard = Character(id: 'guard', name: 'Стражник', vector: [0.2, 0.4], seconds: 2.5);
    const smith = Character(id: 'smith', name: 'Кузнец', vector: [0.1, 0.9], seconds: 3.5);

    /// The canvas with the two cards on it, drawn from settings the test
    /// stages rather than from a disk it does not have.
    Future<DashboardCubits> pumpGraph(
      WidgetTester tester, {
      AppSettings settings = const AppSettings(),
      List<Character> characters = const [guard, smith],
      List<String> placed = const ['guard'],
    }) async {
      final cubits = stage(
        buildCubits(),
        section: DashboardSection.pipeline,
        settings: settings,
        models: catalogue(),
      );
      cubits.characters.seed(CharactersState(characters: characters, loading: false));
      cubits.graph.seed(
        PipelineGraphState(loading: false, layout: PipelineLayout.drawing(placed)),
      );
      await pumpDashboard(tester, cubits, const Size(1500, 950));
      await tester.pump();
      return cubits;
    }

    testWidgets('draws the stages of the pipeline as nodes', (tester) async {
      await pumpGraph(tester);

      expect(find.text('05  /  ПУТЬ СИГНАЛА'), findsOneWidget);
      expect(find.text('Оригинальный поток'), findsOneWidget);
      expect(find.text('Whisper'), findsOneWidget);
      expect(find.text('Перевод'), findsOneWidget);
      expect(find.text('Сведение'), findsOneWidget);
      expect(find.text('Поток'), findsOneWidget);
      expect(find.text('Стражник'), findsOneWidget);
      expect(
        find.text('Кузнец'),
        findsNothing,
        reason: 'only the cards put on the canvas are drawn',
      );
      expect(find.byType(ChoiceChip), findsNothing, reason: 'one route needs no presets');
    });

    testWidgets('asks for no game where the whole output is captured', (tester) async {
      await pumpGraph(
        tester,
        settings: const AppSettings(audioCaptureSource: AudioCaptureSource.system),
      );

      expect(find.text('Игра не выбрана'), findsNothing);
      expect(find.text('Устройство по умолчанию'), findsWidgets);
    });

    testWidgets('holds the game while a card is being recorded', (tester) async {
      final cubits = await pumpGraph(tester);

      await tester.tap(find.text('Оригинальный поток').first);
      await tester.pumpAndSettle();

      final picker = find.byType(DropdownMenu<GameProcess>);
      expect(tester.widget<DropdownMenu<GameProcess>>(picker).enabled, isTrue);

      // The node is a second window onto the same choice, and the characters
      // screen is recording through the game it names.
      cubits.characters.seed(
        const CharactersState(
          loading: false,
          characters: [guard, smith],
          status: PipelineStatus.listening,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        tester.widget<DropdownMenu<GameProcess>>(picker).enabled,
        isFalse,
        reason: 'the recording listens to the game this would change',
      );
    });

    testWidgets('sets the volume and the pace in the same ranges the settings do', (tester) async {
      final cubits = await pumpGraph(tester);

      // The node sits at the far edge of the canvas, where the panel that
      // opens would cover it; selected directly instead of by a tap.
      cubits.graph.add(const PipelineNodeSelected(PipelineNodeIds.output));
      await tester.pumpAndSettle();

      final volume = tester.widget<Slider>(find.byKey(const ValueKey('graphOriginalVolume')));
      expect(volume.min, AppSettings.audibleDuck);
      expect(volume.max, AppSettings.loudestDuck);
      expect(volume.divisions, AppSettings.duckDivisions);
      // Material draws no value over a thumb that carries no label, and the
      // number under the pointer is what the hand watches while it drags.
      expect(volume.label, isNotNull);
      expect(find.text('Приглушать только под перевод'), findsOneWidget);

      cubits.graph.add(const PipelineNodeSelected(PipelineNodeIds.voice));
      await tester.pumpAndSettle();

      final pace = tester.widget<Slider>(find.byKey(const ValueKey('graphTtsSpeed')));
      expect(pace.min, AppSettings.slowestSpeech);
      expect(pace.max, AppSettings.fastestSpeech);
      expect(pace.divisions, AppSettings.speechDivisions);
      expect(pace.label, isNotNull);
      expect(find.text('Ускорять озвучку, когда реплики ждут очереди'), findsOneWidget);
    });

    testWidgets('opens what a node is set to when it is clicked', (tester) async {
      await pumpGraph(tester);

      await tester.tap(find.text('Перевод').first);
      await tester.pumpAndSettle();

      expect(find.text('ВЫБРАНО'), findsOneWidget);
      // Both ends of the stage, and the one that is settled says so: whisper
      // hands English over whatever the game speaks.
      expect(find.text('С какого языка'), findsOneWidget);
      expect(find.text('На какой язык'), findsOneWidget);
      expect(find.textContaining('Whisper отдаёт английский текст'), findsOneWidget);
    });

    testWidgets('slides the panel in from under the frame of the canvas', (tester) async {
      // The panel stood beside the card the scheme is drawn in, and came in
      // from a place to the right of that card which the screen has not got.
      // It is inside the card now, and the card clips: halfway in it is cut
      // off at the frame rather than lying over the page beyond it. It is
      // also moving by then — a panel opening on a canvas with none on it
      // used to wait out the half of the run kept for the one it replaces,
      // and that wait read as a click that had missed the node.
      await pumpGraph(tester);

      await tester.tap(find.text('Перевод').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      final frame = find
          .ancestor(of: find.byType(PipelineCanvas), matching: find.byType(Card))
          .first;
      expect(
        find.descendant(of: frame, matching: find.byType(PipelineInspector)),
        findsOneWidget,
        reason: 'the panel is drawn inside the card that clips the canvas',
      );
      final edge = tester.getRect(frame).right;
      final onItsWay = tester.getRect(find.byType(PipelineInspector));
      expect(onItsWay.left, lessThan(edge), reason: 'part of the panel is out');
      expect(onItsWay.right, greaterThan(edge), reason: 'and the rest is under the frame');

      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(PipelineInspector)).right,
        moreOrLessEquals(edge, epsilon: 0.01),
        reason: 'it comes to rest against that same edge',
      );
    });

    testWidgets('never offers a card the voice of one it already reads', (tester) async {
      // The canvas refuses that line, but the card's own panel used to list
      // the whole cast, so the two could be set to read each other there.
      final cubits = await pumpGraph(tester);
      cubits.characters.seed(
        const CharactersState(
          loading: false,
          characters: [
            Character(id: 'guard', name: 'Стражник', vector: [0.2, 0.4]),
            Character(id: 'smith', name: 'Кузнец', vector: [0.1, 0.9], voicedBy: 'guard'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Стражник').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('graph-reader-guard-null')));
      await tester.pumpAndSettle();

      expect(find.text('Своим голосом'), findsWidgets);
      expect(
        find.text('Кузнец'),
        findsNothing,
        reason: 'the smith is already read by the guard',
      );
    });

    testWidgets('says what each line parts with when it is cut', (tester) async {
      // One tooltip served all three, worded for the substitution alone: the
      // line out of a card into the mix offered to «give the voice back»,
      // which that card was never lent.
      await pumpGraph(
        tester,
        characters: const [
          Character(id: 'guard', name: 'Стражник', vector: [0.2], voicedBy: 'smith'),
          smith,
        ],
        placed: const ['guard', 'smith'],
      );

      expect(find.byTooltip('Отсоединить оригинальный поток'), findsOneWidget);
      expect(find.byTooltip('Убрать персонажей из сведения'), findsOneWidget);
      expect(
        find.byTooltip('Вернуть свой голос'),
        findsOneWidget,
        reason: 'only the line that lends a part offers to take it back',
      );
    });

    testWidgets('rests and wakes the session from the graph itself', (tester) async {
      // The cast is rewired here; walking to Live to pause first would be a
      // walk for nothing.
      final cubits = await pumpGraph(tester);
      expect(find.byKey(const ValueKey('graphPause')), findsNothing);

      cubits.pipeline.seed(const LivePipelineState(status: PipelineStatus.listening));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('graphPause')));
      await tester.pumpAndSettle();

      expect(cubits.pipeline.state.status, PipelineStatus.paused);

      await tester.tap(find.byKey(const ValueKey('graphPause')));
      await tester.pumpAndSettle();

      expect(cubits.pipeline.state.status, PipelineStatus.listening);

      await tester.tap(find.byKey(const ValueKey('graphStop')));
      await tester.pumpAndSettle();

      expect(cubits.pipeline.state.status, PipelineStatus.idle);
      expect(find.byKey(const ValueKey('graphPause')), findsNothing);
    });

    testWidgets('says the lender is read by the card that takes the part', (tester) async {
      // «Стражник» is spoken by «Кузнец»: the line runs out of the card
      // whose part it is and into the card that will speak it, so it is the
      // first that is read in another's voice, not the second.
      await pumpGraph(
        tester,
        characters: const [
          Character(id: 'guard', name: 'Стражник', vector: [0.2], voicedBy: 'smith'),
          smith,
        ],
        placed: const ['guard', 'smith'],
      );

      expect(find.text('Голосом «Кузнец»'), findsOneWidget);
      expect(
        find.text('Своим голосом'),
        findsOneWidget,
        reason: 'the card lending its voice speaks for itself as well',
      );
    });

    testWidgets('renames a character from the node it is drawn as', (tester) async {
      final cubits = await pumpGraph(tester);

      cubits.graph.add(PipelineNodeSelected(PipelineNodeIds.character('guard')));
      await tester.pumpAndSettle();

      final field = find.descendant(
        of: find.byType(PipelineInspector),
        matching: find.byKey(const ValueKey('graph-name-guard')),
      );
      expect(field, findsOneWidget);

      await tester.enterText(field, 'Часовой');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(
        cubits.characters.state.characters.firstWhere((value) => value.id == 'guard').name,
        'Часовой',
      );
      // The node is drawn from the cast, so its own header follows at once.
      expect(find.text('Часовой'), findsWidgets);
      expect(find.text('Стражник'), findsNothing);
    });

    testWidgets('gives the panel buttons room for what they are called', (tester) async {
      final cubits = await pumpGraph(tester);

      cubits.graph.add(PipelineNodeSelected(PipelineNodeIds.character('guard')));
      await tester.pumpAndSettle();

      // Side by side in a panel 320 wide, both labels were cut — one of them
      // across the middle of a word.
      for (final label in ['Персонажи', 'Убрать со схемы']) {
        final text = find.descendant(
          of: find.byType(PipelineInspector),
          matching: find.text(label),
        );
        expect(text, findsOneWidget, reason: label);
        expect(
          tester.getSize(text).height,
          lessThan(24),
          reason: '$label is written on one line',
        );
        expect(
          tester.getSize(text).width,
          greaterThan(60),
          reason: '$label is not squeezed to nothing',
        );
      }
    });

    testWidgets('offers the cast to read a character with', (tester) async {
      final cubits = await pumpGraph(tester);

      await tester.tap(find.text('Стражник').first);
      await tester.pumpAndSettle();

      expect(find.text('Озвучивать как'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Кузнец').last);
      await tester.pumpAndSettle();

      expect(cubits.characters.state.characters.first.voicedBy, 'smith');
      expect(find.text('Кузнец'), findsWidgets, reason: 'the reader joins the canvas');
    });

    testWidgets('picks the game in a field that filters as it is typed', (tester) async {
      final cubits = await pumpGraph(tester);
      cubits.pipeline.seed(
        LivePipelineState(
          processes: [
            for (var index = 0; index < 30; index++)
              GameProcess(
                pid: 1000 + index,
                name: 'conhost.exe',
                path: 'C:/conhost$index.exe',
              ),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Оригинальный поток').first);
      await tester.pumpAndSettle();

      final picker = tester.widget<DropdownMenu<GameProcess>>(
        find.byType(DropdownMenu<GameProcess>),
      );
      expect(picker.enableFilter, isTrue);
      expect(picker.requestFocusOnTap, isTrue);
      expect(
        picker.dropdownMenuEntries.first.label,
        contains('PID 1000'),
        reason: 'two processes of one name are told apart by their pid',
      );
      expect(find.byTooltip('Обновить список процессов'), findsOneWidget);

      final field = find.descendant(
        of: find.byType(DropdownMenu<GameProcess>),
        matching: find.byType(TextField),
      );
      await tester.tap(field);
      await tester.pumpAndSettle();

      final entry = find.text('conhost.exe  ·  PID 1000').hitTestable();
      expect(entry, findsOneWidget);
      expect(
        tester.getTopLeft(entry).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(field).dy),
        reason: 'the list must not slide up over the field it is typed into',
      );
    });

    testWidgets('chooses a second node with shift held', (tester) async {
      final cubits = await pumpGraph(tester);

      await tester.tap(find.text('Whisper'));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.text('Перевод'));
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

      expect(cubits.graph.state.chosen, {
        PipelineNodeIds.recognition,
        PipelineNodeIds.translation,
      });
      // Two nodes have no settings between them, so the panel stays shut.
      expect(cubits.graph.state.selected, isNull);
      expect(find.byType(PipelineInspector), findsNothing);
    });

    testWidgets('draws a band with control held and chooses what it covers', (tester) async {
      final cubits = await pumpGraph(tester);
      final source = tester.getCenter(find.text('Оригинальный поток'));
      final canvas = tester.getRect(find.byType(PipelineCanvas));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      // From an empty corner of the canvas across the first card: a band, not
      // a pan, which is what the modifier is for.
      final gesture = await tester.startGesture(canvas.topLeft + const Offset(6, 6));
      await gesture.moveTo(source + const Offset(20, 20));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(cubits.graph.state.chosen, contains(PipelineNodeIds.source));
      expect(
        cubits.graph.state.layout.view.x,
        PipelineGraphState(layout: cubits.graph.state.layout).layout.view.x,
        reason: 'the canvas stayed where it was',
      );
    });

    testWidgets('carries every chosen node with the one being dragged', (tester) async {
      final cubits = await pumpGraph(tester);
      await tester.tap(find.text('Whisper'));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.text('Перевод'));
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Whisper')),
        kind: PointerDeviceKind.mouse,
      );
      // Past the slop first, so what is measured is drag and nothing else.
      await gesture.moveBy(const Offset(8, 8));
      await tester.pump();
      final was = {
        for (final id in [PipelineNodeIds.recognition, PipelineNodeIds.translation])
          id: cubits.graph.state.graph.node(id)!.position,
      };

      await gesture.moveBy(const Offset(60, 20));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final zoom = cubits.graph.state.layout.view.zoom;
      for (final id in was.keys) {
        final moved = cubits.graph.state.graph.node(id)!.position;
        expect(moved.x - was[id]!.x, closeTo(60 / zoom, 1));
        expect(moved.y - was[id]!.y, closeTo(20 / zoom, 1));
      }
    });

    testWidgets('puts a card on the canvas from the toolbar', (tester) async {
      final cubits = await pumpGraph(tester, placed: const []);

      expect(find.text('Стражник'), findsNothing);
      await tester.tap(find.byIcon(Icons.person_add_alt_rounded));
      // The menu is pushed in the microtask after the tap, so its own frames
      // start only once the first pump has run.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Стражник'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(cubits.graph.state.layout.characters, ['guard']);
      expect(find.text('Стражник'), findsWidgets);
    });

    testWidgets('draws a card again from the toolbar, and says how many are out', (tester) async {
      final cubits = await pumpGraph(tester);

      await tester.tap(find.byIcon(Icons.person_add_alt_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The card already on the canvas is offered again rather than left
      // out: a copy beside the part it takes over keeps the line short.
      expect(find.widgetWithText(PopupMenuItem<String>, 'Стражник'), findsOneWidget);
      expect(find.text('\u00d71'), findsOneWidget, reason: 'one of it is drawn');

      await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Стражник'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(cubits.graph.state.layout.characters, ['guard', 'guard']);
      expect(find.text('Стражник'), findsWidgets);
    });

    testWidgets('offers to write the canvas over a scheme it has kept', (tester) async {
      final cubits = await pumpGraph(tester);
      // A scheme kept when the canvas held nothing, which the canvas has
      // moved on from since. What choosing the item does is the bloc's, and
      // is pinned there; this is that the shelf offers it at all.
      cubits.graph.seed(
        cubits.graph.state.copyWith(
          schemes: const [SavedPipeline(id: 's1', name: 'Вечер в таверне')],
        ),
      );
      await tester.pump();
      await tester.tap(find.textContaining('СОХРАНЁННЫЕ СХЕМЫ'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Вечер в таверне'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Перезаписать'), findsOneWidget);
      expect(find.text('Переименовать'), findsOneWidget);
    });

    testWidgets('takes a card out of the voices the game speaks', (tester) async {
      final cubits = await pumpGraph(tester);
      final counted = cubits.graph.state.graph.linkInto(
        PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.characterIn),
      )!;

      expect(
        find.byTooltip('Не слышать этого персонажа в игре'),
        findsOneWidget,
        reason: 'the dashed line comes apart by the badge on it',
      );

      cubits.graph.add(PipelineLinkCut(counted));
      await tester.pump();
      await tester.pump();

      expect(
        cubits.graph.state.graph.linkInto(
          PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.characterIn),
        ),
        isNull,
      );
      expect(find.text('Стражник'), findsWidgets, reason: 'the card stays where it was put');
    });
  });

  group('the subtitle area', () {
    Future<DashboardCubits> pumpSubtitleArea(
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

/// A runtime store that answers from memory, so the interface can be driven
/// without a disk or a network.
class _RecordingRuntimeRepository extends RuntimeRepository {
  _RecordingRuntimeRepository() : super(RuntimeStorageService());

  final removed = <String>[];
  final installed = <String>[];

  @override
  Future<void> remove(RuntimePackage package) async => removed.add(package.id);

  @override
  Future<DownloadOutcome> install(
    RuntimePackage package, {
    required DownloadProgress onProgress,
    String proxyUrl = '',
    String pythonExecutable = '',
    DownloadControl? control,
  }) async {
    installed.add(package.id);
    return DownloadOutcome.completed;
  }

  @override
  Future<Set<String>> installedIds() async =>
      removed.contains(whisperCudaRuntimeId) ? const {} : const {whisperCudaRuntimeId};

  @override
  Future<String> rootDirectory() async => r'C:\runtime';
}

/// Records the update the interface asked for instead of downloading a setup
/// or closing the test runner.
class _FakeUpdateRepository extends UpdateRepository {
  _FakeUpdateRepository()
    : super(UpdateService(client: _offline), NotificationService(plugin: _silent));

  final downloaded = <String>[];
  final restarted = <String>[];

  @override
  bool get canInstall => true;

  @override
  Future<String?> downloadedInstaller(ReleaseInstaller installer) async => null;

  @override
  Future<String> downloadInstaller(
    ReleaseInstaller installer, {
    required DownloadProgress onProgress,
    String proxyUrl = '',
  }) async {
    onProgress(0.5);
    onProgress(1);
    downloaded.add(installer.name);
    return 'C:\\updates\\${installer.name}';
  }

  @override
  Future<void> restartInto(String setup) async => restarted.add(setup);
}

/// The tests never reach the network: the update check is answered with a
/// refusal, which the interface renders as "could not check".
final http.Client _offline = MockClient(
  (_) async => http.Response('offline', 503),
);

/// A notification plugin that does nothing, so no toast escapes a test run.
final FlutterLocalNotificationsPlugin _silent = FlutterLocalNotificationsPlugin();
