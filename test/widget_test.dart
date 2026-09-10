// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/app.dart';
import 'package:lore_dub/src/data/repositories/app_repository.dart';
import 'package:lore_dub/src/data/repositories/model_repository.dart';
import 'package:lore_dub/src/data/services/model_storage_service.dart';
import 'package:lore_dub/src/data/services/native_engine_service.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/domain/game_process.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart';
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

    expect(find.text('— Японский'), findsOneWidget);
  });

  testWidgets('stays quiet about the language while detection is off', (tester) async {
    final viewModel = buildViewModel()..initializing = false;
    viewModel
      ..settings = viewModel.settings.copyWith(detectSourceLanguage: false)
      ..detectedLanguage = 'ja';
    await pumpDashboard(tester, viewModel, const Size(1280, 720));

    // The list already states the language; repeating it would be noise.
    expect(find.text('— Японский'), findsNothing);
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
