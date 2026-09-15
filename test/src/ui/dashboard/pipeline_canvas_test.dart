// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lore_dub/l10n/app_localizations.dart';
import 'package:lore_dub/src/data/repositories/app_repository.dart';
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
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/pipeline_graph.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/dashboard_cubits.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/downloads_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/pipeline_graph_bloc.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/settings_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/shell_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/dashboard_view.dart';
import 'package:lore_dub/src/ui/dashboard/pipeline_canvas.dart';
import 'package:lore_dub/src/ui/theme.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The graph screen at [size], with every package in place.
  Future<DashboardCubits> pumpGraph(
    WidgetTester tester,
    Size size, {
    AppSettings settings = const AppSettings(),
  }) async {
    SharedPreferences.setMockInitialValues(const {});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cubits = DashboardCubits(
      AppRepository(NativeEngineService(), SettingsService()),
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
    );
    addTearDown(cubits.dispose);
    cubits.shell.seed(const ShellState(section: DashboardSection.pipeline, initializing: false));
    cubits.settings.seed(SettingsState(settings: settings));
    cubits.downloads.seed(
      DownloadsState(
        models: [
          for (final model in modelCatalog) ModelInstallState(model: model, installed: true),
        ],
      ),
    );
    cubits.graph.seed(const PipelineGraphState(loading: false, layout: PipelineLayout()));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLoreDubTheme(),
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: DashboardView(cubits: cubits),
      ),
    );
    await tester.pumpAndSettle();
    return cubits;
  }

  /// The boxes that pick a link up, as they end up on the screen.
  List<Rect> ports(WidgetTester tester) => [
    for (final element
        in find
            .byWidgetPredicate(
              (widget) => widget is MouseRegion && widget.cursor == SystemMouseCursors.precise,
            )
            .evaluate())
      tester.getRect(find.byElementPredicate((other) => other == element)),
  ];

  /// The middle of the one socket of «Оригинальный поток», which is the
  /// port box nearest its title -- the node has no other.
  Offset sourcePort(WidgetTester tester) {
    final title = tester.getCenter(find.text('Оригинальный поток'));
    final boxes = [...ports(tester)]
      ..sort((a, b) => (a.center - title).distance.compareTo((b.center - title).distance));
    return boxes.first.center;
  }

  testWidgets('drops a link on a card rather than on its socket', (tester) async {
    // Aiming at a dot six pixels across is needless when the card has one
    // socket the link could go into: let go anywhere on it and that socket
    // catches the link.
    final cubits = await pumpGraph(
      tester,
      const Size(1500, 950),
      settings: const AppSettings(captureRouted: false),
    );

    final gesture = await tester.startGesture(sourcePort(tester), kind: PointerDeviceKind.mouse);
    // Past the slop, then onto the title of Whisper -- the far side of the
    // card from the socket that answers, which sits on its left edge.
    await gesture.moveBy(const Offset(8, 8));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.text('Whisper')));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump();

    expect(cubits.settings.state.settings.captureRouted, isTrue);
  });

  testWidgets('leaves a card alone when nothing on it takes the link', (tester) async {
    // The output has one socket and it carries audio of the finished
    // dubbing: the game's sound has no business in it, and the card says so
    // rather than swallowing the link.
    final cubits = await pumpGraph(
      tester,
      const Size(1500, 950),
      settings: const AppSettings(captureRouted: false),
    );

    final gesture = await tester.startGesture(sourcePort(tester), kind: PointerDeviceKind.mouse);
    await gesture.moveBy(const Offset(8, 8));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.text('Поток')));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump();

    expect(cubits.settings.state.settings.captureRouted, isFalse);
  });

  testWidgets('holds the grab target to one size on screen at any zoom', (tester) async {
    // A scheme fitted into a small window is drawn small, but the pointer is
    // the size it always was: the boxes that pick a link up are measured on
    // the screen rather than on the canvas, or a dot six pixels across
    // cannot be taken hold of at all.
    final wide = await pumpGraph(tester, const Size(1500, 950));
    final atWide = ports(tester);
    final wideZoom = wide.graph.state.layout.view.zoom;

    final narrow = await pumpGraph(tester, const Size(960, 640));
    final atNarrow = ports(tester);
    final narrowZoom = narrow.graph.state.layout.view.zoom;

    expect(atWide, isNotEmpty);
    expect(atNarrow.length, atWide.length);
    expect(narrowZoom, lessThan(wideZoom), reason: 'the smaller window fits the scheme smaller');

    for (final rect in [...atWide, ...atNarrow]) {
      expect(rect.width, closeTo(NodeMetrics.grabReach * 2, 0.01));
    }
    for (final (index, rect) in atNarrow.indexed) {
      expect(
        rect.height,
        lessThanOrEqualTo(NodeMetrics.rowHeight * narrowZoom + 0.01),
        reason: 'port $index must not cover the socket under it',
      );
      expect(rect.height, greaterThan(0));
      expect(
        rect.height,
        lessThanOrEqualTo(atWide[index].height + 0.01),
        reason: 'the row it sits in is drawn smaller too',
      );
    }
  });

  testWidgets('selects every node it is clicked on, near or far', (tester) async {
    // A child drawn outside its parent is painted but not hit, and the nodes
    // are laid out well past the width of the window: «Сведение» and «Поток»
    // could be seen and dragged and never clicked, while the four before
    // them answered. The canvas lays a box of its own under them for this.
    final cubits = await pumpGraph(tester, const Size(1500, 950));

    const titles = {
      'Оригинальный поток': PipelineNodeIds.source,
      'Whisper': PipelineNodeIds.recognition,
      'Перевод': PipelineNodeIds.translation,
      'Реплики': PipelineNodeIds.voice,
      'Сведение': PipelineNodeIds.mix,
      'Поток': PipelineNodeIds.output,
    };
    for (final entry in titles.entries) {
      for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
        cubits.graph.add(const PipelineNodeSelected(null));
        await tester.pumpAndSettle();

        await tester.tap(find.text(entry.key).first, kind: kind);
        await tester.pumpAndSettle();

        expect(cubits.graph.state.selected, entry.value, reason: '${entry.key} by $kind');
      }
    }
  });

  testWidgets('keeps a dragged node under the pointer', (tester) async {
    final cubits = await pumpGraph(tester, const Size(1500, 950));
    final zoom = cubits.graph.state.layout.view.zoom;
    final card = find.text('Перевод');

    final gesture = await tester.startGesture(
      tester.getCenter(card.first),
      kind: PointerDeviceKind.mouse,
    );
    // Past the slop first, so what is measured below is drag and nothing else.
    await gesture.moveBy(const Offset(8, 8));
    await tester.pump();
    final from = tester.getCenter(card.first);
    final before = cubits.graph.state.graph.node(PipelineNodeIds.translation)!.position;

    await gesture.moveBy(const Offset(120, 60));
    await tester.pump();

    final after = cubits.graph.state.graph.node(PipelineNodeIds.translation)!.position;
    final moved = tester.getCenter(card.first) - from;
    await gesture.up();

    // The card goes exactly as far as the pointer, whatever the canvas is
    // scaled to. Measured against the drag's own delta it ran ahead: that is
    // reported in the card's coordinates, and the card moves out from under
    // the pointer as it goes, so every step was measured against a card that
    // had already answered the one before it.
    expect(moved.dx, closeTo(120, 0.5), reason: 'the pointer moved 120 across');
    expect(moved.dy, closeTo(60, 0.5), reason: 'and 60 down');
    // Which is that distance in the coordinates the scheme is laid out in.
    expect(after.x - before.x, closeTo(120 / zoom, 0.5));
    expect(after.y - before.y, closeTo(60 / zoom, 0.5));
  });
}
