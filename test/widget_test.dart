// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
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
import 'package:lore_dub/src/domain/failure.dart';
import 'package:lore_dub/src/domain/game_process.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/ocr_region.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart' show PipelineStatus, TranscriptEntry;
import 'package:lore_dub/src/domain/runtime_package.dart';
import 'package:lore_dub/src/ui/dashboard/dashboard_view.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/dashboard_cubits.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/downloads_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/pipeline_cubit.dart';
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
    expect(find.text('01  /  LIVE VOICE'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
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

    await tester.tap(find.text('Весь звук'));
    await tester.pumpAndSettle();

    picker = tester.widget<DropdownMenu<GameProcess>>(pickerFinder);
    expect(picker.enabled, isFalse);
    expect(
      find.text('Захватывается весь дефолтный поток, кроме звука LoreDub'),
      findsOneWidget,
    );
  });

  testWidgets('names the audio path while dubbing what the game says', (tester) async {
    final cubits = stage(buildCubits(), settings: const AppSettings());
    await pumpDashboard(tester, cubits, const Size(1280, 720));

    expect(find.text('Захватывается только звук выбранного процесса'), findsOneWidget);
    expect(find.text('Whisper → English → Marian → Русский → Silero'), findsOneWidget);
  });

  testWidgets('says subtitle mode reads the window rather than the audio', (tester) async {
    final cubits = stage(
      buildCubits(),
      settings: const AppSettings(captureMode: CaptureMode.ocr),
    );
    await pumpDashboard(tester, cubits, const Size(1280, 720));

    expect(
      find.text('Субтитры читаются с окна выбранной игры, пока оно активно'),
      findsOneWidget,
    );
    expect(find.text('Windows OCR → English → Marian → Русский → Silero'), findsOneWidget);
    expect(find.textContaining('звук выбранного процесса'), findsNothing);
    expect(find.textContaining('Whisper'), findsNothing);
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

  testWidgets('splits the models screen into recognition, translation and voices', (
    tester,
  ) async {
    final cubits = stage(
      buildCubits(),
      section: DashboardSection.models,
      models: catalogue(installed: false),
    );
    await pumpDashboard(tester, cubits, const Size(1280, 900));

    expect(find.text('РАСПОЗНАВАНИЕ РЕЧИ'), findsOneWidget);
    expect(find.text('МОДЕЛИ ДЛЯ ПЕРЕВОДА ТЕКСТА'), findsOneWidget);
    expect(find.text('Whisper base'), findsOneWidget);

    // The voices sit below the fold of a lazy list.
    await tester.scrollUntilVisible(find.text('МОДЕЛИ ДЛЯ ОЗВУЧИВАНИЯ ТЕКСТА'), 400);
    expect(find.text('МОДЕЛИ ДЛЯ ОЗВУЧИВАНИЯ ТЕКСТА'), findsOneWidget);
    final selection = cubits.selection;
    expect(selection.recognitionModels.length, greaterThan(1), reason: 'the model is a choice');
    expect(selection.translationModels.length, greaterThan(1));
    expect(selection.speechModels.length, greaterThan(1));
  });

  testWidgets('picks the language by tapping its card in either section', (tester) async {
    final cubits = stage(
      buildCubits(),
      section: DashboardSection.models,
      models: catalogue(installed: false),
    );
    await pumpDashboard(tester, cubits, const Size(1280, 900));

    await tester.scrollUntilVisible(find.text('Английский → немецкий'), 400);
    await tester.ensureVisible(find.text('Английский → немецкий'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Английский → немецкий'));
    await tester.pumpAndSettle();
    expect(cubits.settings.settings.targetLanguage, 'de');

    await tester.scrollUntilVisible(find.text('Русский голос — Silero v5.3'), 400);
    await tester.ensureVisible(find.text('Русский голос — Silero v5.3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Русский голос — Silero v5.3'));
    await tester.pumpAndSettle();
    expect(cubits.settings.settings.targetLanguage, 'ru');
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
    await tester.scrollUntilVisible(proxyField, 300, scrollable: find.byType(Scrollable).first);
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
    await tester.scrollUntilVisible(section, 300, scrollable: find.byType(Scrollable).first);
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

  testWidgets('never offers speech anything but the processor', (tester) async {
    await pumpLoreDub(tester, const Size(1280, 900));
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();

    final speech = find.text('Озвучка');
    await tester.scrollUntilVisible(speech, 300, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    // Silero has no GPU build here, so its row carries a single chip.
    final row = find.ancestor(of: speech, matching: find.byType(Row)).first;
    expect(find.descendant(of: row, matching: find.byType(ChoiceChip)), findsOneWidget);
  });

  testWidgets('remembers the compute preset the user pressed', (tester) async {
    await pumpLoreDub(tester, const Size(1280, 900));
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();

    final section = find.text('Вычислительное устройство');
    await tester.scrollUntilVisible(section, 300, scrollable: find.byType(Scrollable).first);
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
    await tester.scrollUntilVisible(message, 300, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    expect(message, findsOneWidget);
    expect(find.textContaining('OSError'), findsOneWidget);
    expect(
      find.textContaining('Скачать · 2.5 GB'),
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
        find.textContaining('Удалить · '),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('asks before giving hundreds of megabytes back', (tester) async {
      await stageInstalledRuntime(tester);

      await tester.tap(find.textContaining('Удалить · '));
      await tester.pumpAndSettle();

      expect(find.text('Точно удалить?'), findsOneWidget);
      expect(find.text('Удалить полностью'), findsOneWidget);
      expect(find.text('Оставить'), findsOneWidget);
      expect(runtimes.removed, isEmpty, reason: 'asking must not act');
    });

    testWidgets('names the size that is about to be freed', (tester) async {
      await stageInstalledRuntime(tester);

      await tester.tap(find.textContaining('Удалить · '));
      await tester.pumpAndSettle();

      expect(find.textContaining('436 MB'), findsWidgets);
    });

    testWidgets('keeps the runtime when the question is declined', (tester) async {
      await stageInstalledRuntime(tester);

      await tester.tap(find.textContaining('Удалить · '));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Оставить'));
      await tester.pumpAndSettle();

      expect(find.text('Точно удалить?'), findsNothing);
      expect(runtimes.removed, isEmpty);
      expect(find.textContaining('Удалить · '), findsOneWidget);
    });

    testWidgets('removes it once the question is answered', (tester) async {
      await stageInstalledRuntime(tester);

      await tester.tap(find.textContaining('Удалить · '));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить полностью'));
      await tester.pumpAndSettle();

      expect(find.text('Точно удалить?'), findsNothing);
      expect(runtimes.removed, [whisperCudaRuntimeId]);
      expect(
        find.textContaining('Удалить · '),
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

    testWidgets('offers the release page once a newer version exists', (tester) async {
      final cubits = withUpdates(
        UpdateState(
          status: UpdateStatus.available,
          currentVersion: '0.2.1',
          release: AppRelease(
            version: '0.3.0',
            page: Uri.parse('https://github.com/Hecatoncheir/LoreDub/releases/tag/v0.3.0'),
          ),
        ),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      expect(find.byIcon(Icons.arrow_outward_rounded), findsOneWidget);
      expect(find.byTooltip('Открыть страницу версии 0.3.0'), findsOneWidget);
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
      expect(find.textContaining('Приостановлено'), findsOneWidget);
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

    testWidgets('a paused download is resumed by its own button', (tester) async {
      await pumpDownloading(tester, paused: true);

      // The whisper card is the paused one; its download button is out of
      // action while the part waits to be continued.
      final card = find.ancestor(
        of: find.textContaining('Приостановлено'),
        matching: find.byType(Card),
      );
      final button = tester.widget<OutlinedButton>(
        find.descendant(of: card, matching: find.byType(OutlinedButton)),
      );

      expect(button.onPressed, isNull);
      expect(find.descendant(of: card, matching: find.byTooltip('Продолжить')), findsOneWidget);
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

      expect(find.text('Whisper base'), findsOneWidget);
      expect(find.text('Whisper small'), findsOneWidget);
      expect(
        cubits.selection.recognition?.model.id,
        whisperModelId,
        reason: 'an unset choice falls back to the smallest',
      );
    });

    testWidgets('remembers the model tapped in the list', (tester) async {
      final cubits = await pumpModels(tester);

      await tester.scrollUntilVisible(find.text('Whisper small'), 300);
      await tester.ensureVisible(find.text('Whisper small'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Whisper small'));
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
        scrollable: find.byType(Scrollable).first,
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

    testWidgets('says why the voice cannot follow a subtitle stream', (tester) async {
      final cubits = await pumpSettings(
        tester,
        settings: const AppSettings(captureMode: CaptureMode.ocr),
      );

      expect(cubits.selection.canFollowSpeaker, isFalse);
      expect(find.textContaining('субтитров'), findsOneWidget);
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
        find.textContaining('Тембр берётся из каждой реплики заново'),
        findsOneWidget,
        reason: 'the voice bank starts off',
      );
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

      expect((await SettingsService().load()).overlapVoices, isFalse);
    });

    testWidgets('hides overlapping when one voice reads every line', (tester) async {
      await pumpSettings(tester, settings: const AppSettings(automaticVoice: false));

      expect(find.text('Накладывать реплики разных персонажей'), findsNothing);
    });

    Finder clearButton() => find.ancestor(
      of: find.text('Очистить'),
      matching: find.byWidgetPredicate((widget) => widget is TextButton),
    );

    testWidgets('remembers the characters only once asked', (tester) async {
      await pumpSettings(tester, settings: const AppSettings(originalVoice: true));

      expect(find.text('Сохранённых голосов нет'), findsOneWidget);
      expect(
        tester.widget<TextButton>(clearButton()).onPressed,
        isNull,
        reason: 'there is nothing to clear',
      );

      final row = find.ancestor(
        of: find.text('Запоминать голоса персонажей'),
        matching: find.byType(Row),
      );
      await tester.tap(find.descendant(of: row.first, matching: find.byType(Switch)));
      await tester.pumpAndSettle();

      expect((await SettingsService().load()).voiceBank, isTrue);
      expect(find.textContaining('У каждой игры свой банк'), findsOneWidget);
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
        find.textContaining('Silero считается на процессоре'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('OpenVoice'), findsNothing);
    });

    testWidgets('gives OpenVoice a device of its own with the original voice', (tester) async {
      await pumpSettings(tester, settings: const AppSettings(originalVoice: true));
      await tester.scrollUntilVisible(
        find.text('OpenVoice'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('OpenVoice'), findsOneWidget);
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
        section: DashboardSection.settings,
        settings: AppSettings(captureMode: CaptureMode.ocr, ocrRegion: region),
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

  @override
  Future<void> remove(RuntimePackage package) async => removed.add(package.id);

  @override
  Future<Set<String>> installedIds() async =>
      removed.contains(whisperCudaRuntimeId) ? const {} : const {whisperCudaRuntimeId};

  @override
  Future<String> rootDirectory() async => r'C:\runtime';
}

/// The tests never reach the network: the update check is answered with a
/// refusal, which the interface renders as "could not check".
final http.Client _offline = MockClient(
  (_) async => http.Response('offline', 503),
);

/// A notification plugin that does nothing, so no toast escapes a test run.
final FlutterLocalNotificationsPlugin _silent = FlutterLocalNotificationsPlugin();
