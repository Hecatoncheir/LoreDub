// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/l10n/app_localizations.dart';
import 'package:lore_dub/src/app.dart';
import 'package:lore_dub/src/domain/spoken_language.dart';
import 'package:lore_dub/src/data/repositories/app_repository.dart';
import 'package:lore_dub/src/data/repositories/model_repository.dart';
import 'package:lore_dub/src/data/services/model_catalog.dart';
import 'package:lore_dub/src/data/services/model_storage_service.dart';
import 'package:lore_dub/src/data/services/native_engine_service.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/domain/game_process.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart' show PipelineStatus, TranscriptEntry;
import 'package:lore_dub/src/ui/dashboard/dashboard_view.dart';
import 'package:lore_dub/src/ui/dashboard/dashboard_view_model.dart';
import 'package:lore_dub/src/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  DashboardViewModel buildViewModel() {
    SharedPreferences.setMockInitialValues({});
    final viewModel = DashboardViewModel(
      AppRepository(NativeEngineService(), SettingsService()),
      ModelRepository(ModelStorageService()),
    );
    addTearDown(viewModel.dispose);
    return viewModel;
  }

  /// Drives the dashboard from a view model the test owns, so pipeline states
  /// can be shown without starting anything.
  Future<void> pumpDashboard(WidgetTester tester, DashboardViewModel viewModel, Size size) async {
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
        home: DashboardView(viewModel: viewModel),
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
    final viewModel = buildViewModel()
      ..initializing = false
      ..status = PipelineStatus.starting
      ..startupProgress = 0.35
      ..startupStage = 'Загрузка Transformers';
    await pumpDashboard(tester, viewModel, const Size(1280, 720));

    expect(find.text('Запуск 35%'), findsOneWidget);
    expect(find.text('Загрузка Transformers'), findsOneWidget);
    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(indicator.value, 0.35);
  });

  testWidgets('drops the progress indicator once the pipeline listens', (tester) async {
    final viewModel = buildViewModel()
      ..initializing = false
      ..status = PipelineStatus.listening;
    await pumpDashboard(tester, viewModel, const Size(1280, 720));

    expect(find.text('Остановить'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('names the language auto-detection settled on', (tester) async {
    final viewModel = buildViewModel()
      ..initializing = false
      ..detectedLanguage = 'ja';
    await pumpDashboard(tester, viewModel, const Size(1280, 720));

    expect(find.text('Определён: Японский'), findsOneWidget);
    expect(find.text('Определять язык'), findsNothing, reason: 'the answer takes its place');
  });

  testWidgets('goes back to the plain toggle label once stopped', (tester) async {
    final viewModel = buildViewModel()
      ..initializing = false
      ..status = PipelineStatus.listening
      ..detectedLanguage = 'ja';
    await pumpDashboard(tester, viewModel, const Size(1280, 720));
    expect(find.text('Определён: Японский'), findsOneWidget);

    await viewModel.togglePipeline();
    await tester.pumpAndSettle();

    expect(viewModel.detectedLanguage, isNull);
    expect(find.text('Определять язык'), findsOneWidget);
    expect(find.text('Определён: Японский'), findsNothing);
  });

  testWidgets('stays quiet about the language while detection is off', (tester) async {
    final viewModel = buildViewModel()..initializing = false;
    viewModel
      ..settings = viewModel.settings.copyWith(detectSourceLanguage: false)
      ..detectedLanguage = 'ja';
    await pumpDashboard(tester, viewModel, const Size(1280, 720));

    // The list already states the language; repeating it would be noise.
    expect(find.text('Определён: Японский'), findsNothing);
  });

  testWidgets('shows a phrase as a bubble with its time beside the tail', (tester) async {
    final viewModel = buildViewModel()
      ..initializing = false
      ..transcript = [
        const TranscriptEntry(
          original: 'The gate is sealed.',
          english: 'The gate is sealed.',
          translated: 'Ворота закрыты.',
          latency: Duration(milliseconds: 1325),
        ),
      ];
    await pumpDashboard(tester, viewModel, const Size(1280, 720));

    expect(find.text('The gate is sealed.'), findsOneWidget);
    expect(find.text('Ворота закрыты.'), findsOneWidget);
    expect(find.text('1325 мс'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets, reason: 'the bubble tail is painted');
  });

  testWidgets('falls back to the recognized English when there is no original', (tester) async {
    final viewModel = buildViewModel()
      ..initializing = false
      ..transcript = [
        const TranscriptEntry(
          original: '',
          english: 'Take cover.',
          translated: 'В укрытие.',
          latency: Duration(milliseconds: 900),
        ),
      ];
    await pumpDashboard(tester, viewModel, const Size(1280, 720));

    expect(find.text('Take cover.'), findsOneWidget);
    expect(find.text('900 мс'), findsOneWidget);
  });

  testWidgets('picks the dubbing language beside the start button', (tester) async {
    final viewModel = buildViewModel()
      ..initializing = false
      ..models = [
        for (final model in modelCatalog)
          ModelInstallState(model: model, installed: model.language != 'de'),
      ];
    await pumpDashboard(tester, viewModel, const Size(1280, 720));

    final picker = find.byKey(const ValueKey('targetLanguage'));
    expect(picker, findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);

    final field = tester.widget<DropdownButtonFormField<String>>(picker);
    field.onChanged!('fr');
    await tester.pumpAndSettle();

    // The choice is the models choice: the French pair is now the one used.
    expect(viewModel.settings.targetLanguage, 'fr');
    expect((await SettingsService().load()).targetLanguage, 'fr');
    expect(viewModel.requiredModelsInstalled, isTrue);
  });

  testWidgets('marks a language whose models are missing', (tester) async {
    final viewModel = buildViewModel()
      ..initializing = false
      ..models = [
        for (final model in modelCatalog)
          ModelInstallState(model: model, installed: model.language != 'de'),
      ];
    await pumpDashboard(tester, viewModel, const Size(1280, 720));

    expect(viewModel.isLanguageReady('ru'), isTrue);
    expect(viewModel.isLanguageReady('de'), isFalse);

    await tester.tap(find.byKey(const ValueKey('targetLanguage')));
    await tester.pumpAndSettle();
    expect(find.text('Немецкий · нет моделей'), findsWidgets);
  });

  testWidgets('splits the models screen into recognition, translation and voices', (
    tester,
  ) async {
    final viewModel = buildViewModel()
      ..initializing = false
      ..section = DashboardSection.models
      ..models = [
        for (final model in modelCatalog) ModelInstallState(model: model),
      ];
    await pumpDashboard(tester, viewModel, const Size(1280, 900));

    expect(find.text('РАСПОЗНАВАНИЕ РЕЧИ'), findsOneWidget);
    expect(find.text('МОДЕЛИ ДЛЯ ПЕРЕВОДА ТЕКСТА'), findsOneWidget);
    expect(find.text('Whisper base'), findsOneWidget);

    // The voices sit below the fold of a lazy list.
    await tester.scrollUntilVisible(find.text('МОДЕЛИ ДЛЯ ОЗВУЧИВАНИЯ ТЕКСТА'), 400);
    expect(find.text('МОДЕЛИ ДЛЯ ОЗВУЧИВАНИЯ ТЕКСТА'), findsOneWidget);
    expect(viewModel.recognitionModels, hasLength(1));
    expect(viewModel.translationModels.length, greaterThan(1));
    expect(viewModel.speechModels.length, greaterThan(1));
  });

  testWidgets('picks the language by tapping its card in either section', (tester) async {
    final viewModel = buildViewModel()
      ..initializing = false
      ..section = DashboardSection.models
      ..models = [for (final model in modelCatalog) ModelInstallState(model: model)];
    await pumpDashboard(tester, viewModel, const Size(1280, 900));

    await tester.tap(find.text('Английский → немецкий'));
    await tester.pumpAndSettle();
    expect(viewModel.settings.targetLanguage, 'de');

    await tester.scrollUntilVisible(find.text('Русский голос — Silero v5.3'), 400);
    await tester.tap(find.text('Русский голос — Silero v5.3'));
    await tester.pumpAndSettle();
    expect(viewModel.settings.targetLanguage, 'ru');
  });

  testWidgets('needs only the pair of the chosen language', (tester) async {
    final viewModel = buildViewModel()..initializing = false;
    viewModel.models = [
      for (final model in modelCatalog)
        ModelInstallState(
          model: model,
          installed: model.language == null || model.language == 'ru',
        ),
    ];
    await pumpDashboard(tester, viewModel, const Size(1280, 720));

    expect(viewModel.settings.targetLanguage, 'ru');
    expect(viewModel.requiredModelsInstalled, isTrue);

    await viewModel.selectTargetLanguage('de');

    expect(
      viewModel.requiredModelsInstalled,
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

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();

    final proxyField = find.widgetWithText(
      TextFormField,
      'HTTP / SOCKS5 proxy',
    );
    await tester.ensureVisible(proxyField);
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
}
