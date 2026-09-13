// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The graph screen at [size], with every package in place.
  Future<DashboardCubits> pumpGraph(WidgetTester tester, Size size) async {
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
    cubits.settings.seed(const SettingsState(settings: AppSettings()));
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
}
