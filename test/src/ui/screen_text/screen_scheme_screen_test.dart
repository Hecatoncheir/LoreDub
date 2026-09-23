// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// The Screen page's other half: the scheme its reading runs by, switched to
// by the page's own title, as Эфир's is.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/l10n/app_localizations.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/pipeline_graph.dart';
import 'package:lore_dub/src/ui/graph/canvas/pipeline_canvas.dart';
import 'package:lore_dub/src/ui/graph/inspector/pipeline_inspector.dart';
import 'package:lore_dub/src/ui/screen_text/screen_layout.dart';
import 'package:lore_dub/src/ui/screen_text/screen_title_switch.dart';
import 'package:lore_dub/src/ui/screen_text/snapshot_panel.dart';
import 'package:lore_dub/src/ui/shell/dashboard_header.dart';
import 'package:lore_dub/src/ui/shell/bloc/navigation_cubit.dart';

import '../../../support/dashboard_harness.dart';
import '../../../support/mock_blocs.dart';
import '../../../support/staged_dashboard.dart';

void main() {
  // What `captureAny` stands in with before anything is captured.
  setUpAll(registerEventFallbacks);

  Finder onCanvas(Finder finder) =>
      find.descendant(of: find.byType(PipelineCanvas), matching: finder);
  Finder inPanel(Finder finder) =>
      find.descendant(of: find.byType(PipelineInspector), matching: finder);

  /// Every package, with the converter on disk or not.
  List<ModelInstallState> packages({bool converter = true}) => [
    for (final install in catalogue())
      ModelInstallState(
        model: install.model,
        installed: converter || install.model.kind != ModelKind.voiceConversion,
      ),
  ];

  /// The Screen page, open on [view].
  Future<StagedDashboard> pumpScreen(
    WidgetTester tester, {
    ScreenView view = ScreenView.scheme,
    AppSettings settings = const AppSettings(),
    bool converter = true,
  }) async {
    final cubits = stage(
      buildCubits(),
      section: DashboardSection.snapshot,
      screenView: view,
      settings: settings,
      models: packages(converter: converter),
    );
    cubits.stageScreenScheme();
    await pumpDashboard(tester, cubits, const Size(1500, 950));
    await tester.pump();
    return cubits;
  }

  /// Opens the panel of the node titled [title].
  Future<void> open(WidgetTester tester, String title) async {
    await tester.tap(onCanvas(find.text(title)).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('switches between the reading and its scheme by the page\'s title', (tester) async {
    final cubits = await pumpScreen(tester, view: ScreenView.reading);

    expect(find.text('02  /  ТЕКСТ С ЭКРАНА'), findsOneWidget);
    expect(find.text('Перевод с экрана'), findsOneWidget);
    expect(find.byType(SnapshotPanel), findsOneWidget);

    await tester.tap(find.text('Схема'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(cubits.navigation.state.screenView, ScreenView.scheme);
    expect(find.text('02  /  ПУТЬ СИГНАЛА'), findsOneWidget);
    expect(find.byType(SnapshotPanel), findsNothing);
    expect(onCanvas(find.text('Определение персонажа')), findsOneWidget);

    await tester.tap(find.text('Перевод с экрана'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(SnapshotPanel), findsOneWidget);
    expect(cubits.navigation.state.liveView, LiveView.dubbing, reason: 'Эфир keeps its own half');
  });

  testWidgets('keeps each page\'s half where it was left', (tester) async {
    final cubits = await pumpScreen(tester);

    cubits.navigation.selectSection(DashboardSection.live);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('01  /  ЖИВОЙ ГОЛОС'), findsOneWidget);

    cubits.navigation.selectSection(DashboardSection.snapshot);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('02  /  ПУТЬ СИГНАЛА'), findsOneWidget);
  });

  testWidgets('draws the screen, the game\'s sound and the stream, and no whisper', (
    tester,
  ) async {
    final cubits = await pumpScreen(tester);

    for (final title in [
      'Оригинальный поток',
      'Определение персонажа',
      'Экран',
      'Перевод',
      'Реплики',
      'Сведение',
      'Поток',
    ]) {
      expect(onCanvas(find.text(title)), findsOneWidget, reason: title);
    }
    expect(onCanvas(find.text('Whisper')), findsNothing);
    expect(onCanvas(find.text('WINDOWS OCR · АНГЛИЙСКИЙ')), findsOneWidget);
    expect(
      cubits.screenGraph.state.graph.node(PipelineNodeIds.detection)?.unrouted,
      isTrue,
      reason: 'the voices are not listened for until switched on',
    );
  });

  testWidgets('opens the detection on its switch, with what the frame\'s card says under it', (
    tester,
  ) async {
    final cubits = await pumpScreen(tester);

    await open(tester, 'Определение персонажа');

    expect(inPanel(find.text('Определять голоса персонажей')), findsOneWidget);
    expect(inPanel(find.textContaining('Пока субтитры читаются')), findsOneWidget);

    await tester.tap(inPanel(find.byType(Switch)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(cubits.settingsRepository.settings.screenVoices, isTrue);
    expect(
      cubits.screenGraph.state.graph.linkInto(
        const PipelinePort(PipelineNodeIds.voice, PipelineSocket.voiceSpeaker),
      ),
      isNotNull,
      reason: 'the switch draws the route in',
    );
  });

  testWidgets('throws the same switch on the detection\'s card', (tester) async {
    final cubits = await pumpScreen(tester, settings: const AppSettings(screenVoices: true));

    final onCard = onCanvas(find.byType(Switch));
    expect(onCard, findsOneWidget, reason: 'the detection is the one card with a switch');
    expect(tester.widget<Switch>(onCard).value, isTrue);

    await tester.tap(onCard);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(cubits.settingsRepository.settings.screenVoices, isFalse);
    expect(tester.widget<Switch>(onCard).value, isFalse);
    expect(onCanvas(find.text('НЕ ПОДКЛЮЧЕНО')), findsWidgets);
  });

  testWidgets('waits for the converter, and says where to get it', (tester) async {
    await pumpScreen(tester, converter: false);

    expect(onCanvas(find.text('Нужен конвертер голоса')), findsOneWidget);
    await open(tester, 'Определение персонажа');

    expect(inPanel(find.textContaining('Нужен конвертер голоса: скачайте')), findsOneWidget);
    expect(tester.widget<Switch>(inPanel(find.byType(Switch))).onChanged, isNull);
  });

  testWidgets('reads the screen in one voice, with nothing of Эфир\'s modes', (tester) async {
    await pumpScreen(tester);

    await open(tester, 'Реплики');

    expect(inPanel(find.text('Голос для чтения')), findsNothing);
    expect(inPanel(find.byType(ChoiceChip)), findsNothing, reason: 'no mode to choose');
    expect(inPanel(find.textContaining('Реплики с экрана читаются этим голосом')), findsOneWidget);
  });

  testWidgets('says what the screen is read off, and offers the window or the screen', (
    tester,
  ) async {
    await pumpScreen(tester);

    await open(tester, 'Экран');

    expect(inPanel(find.text('Окно игры')), findsOneWidget);
    expect(inPanel(find.text('Весь экран')), findsOneWidget);
    expect(inPanel(find.textContaining('Текст берётся с экрана')), findsOneWidget);
  });

  testWidgets('offers a cut that reads the screen without translation', (tester) async {
    await pumpScreen(tester);

    expect(find.byTooltip('Читать текст с экрана без перевода'), findsWidgets);
    expect(
      find.byTooltip('Убрать перевод из линии: озвучка пойдёт на английском'),
      findsNothing,
      reason: 'Эфир\'s cut dubs into English; the screen\'s reads the text as it is',
    );
  });

  testWidgets('offers the voices\' own cut once they are drawn in', (tester) async {
    await pumpScreen(tester, settings: const AppSettings(screenVoices: true));

    expect(find.byTooltip('Не определять голоса персонажей'), findsNWidgets(2));
  });

  for (final size in [const Size(900, 700), const Size(640, 800)]) {
    testWidgets('keeps the page\'s title inside the header of $size', (tester) async {
      final cubits = stage(buildCubits(), section: DashboardSection.snapshot, models: catalogue());
      cubits.stageScreenScheme();
      await pumpDashboard(tester, cubits, size);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.descendant(of: find.byType(DashboardHeader), matching: find.text('Перевод с экрана')),
        findsOneWidget,
      );
    });
  }

  group('the title in a header of its own width', () {
    Future<NavigationCubit> pumpTitle(WidgetTester tester, double width) async {
      final navigation = NavigationCubit();
      addTearDown(navigation.close);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: BlocProvider.value(
            value: navigation,
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: width, child: const ScreenTitleSwitch()),
              ),
            ),
          ),
        ),
      );
      return navigation;
    }

    testWidgets('names both halves where there is room', (tester) async {
      await pumpTitle(tester, ScreenLayout.titleSwitchWidth);

      expect(find.text('Перевод с экрана'), findsOneWidget);
      expect(find.text('Схема'), findsOneWidget);
    });

    testWidgets('stands the half that is not up as its mark where there is not', (
      tester,
    ) async {
      final navigation = await pumpTitle(tester, ScreenLayout.titleSwitchWidth - 1);

      expect(find.text('Перевод с экрана'), findsOneWidget);
      expect(find.text('Схема'), findsNothing);
      expect(find.byTooltip('Схема'), findsOneWidget, reason: 'named for the pointer');

      await tester.tap(find.byIcon(Icons.account_tree_rounded));
      await tester.pump();

      expect(navigation.state.screenView, ScreenView.scheme);
      expect(navigation.state.section, DashboardSection.snapshot);
      expect(find.text('Схема'), findsOneWidget, reason: 'the half that is up is named');
      expect(find.byTooltip('Перевод с экрана'), findsOneWidget);
    });
  });
}
