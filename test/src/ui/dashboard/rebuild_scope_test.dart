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
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart';
import 'package:lore_dub/src/domain/spoken_language.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/dashboard_cubits.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/downloads_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/pipeline_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/shell_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/dashboard_view.dart';
import 'package:lore_dub/src/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What one report of download progress costs the rest of the screen.
///
/// The dashboard is split across four cubits so a part listens only to what
/// it draws. Nothing enforces that but this: a single listener put back at
/// the root would pass every other test and quietly redraw everything.
void main() {
  /// How many mounted elements were handed a new widget by [change].
  ///
  /// A rebuilt element gets a fresh widget object; one that was left alone
  /// keeps the instance it already had.
  Future<int> rebuiltBy(WidgetTester tester, VoidCallback change) async {
    final before = <Element, Widget>{
      for (final element in tester.allElements) element: element.widget,
    };
    change();
    // Twice: a cubit hands its state to listeners a microtask later, and the
    // frame that draws it is the one after that.
    await tester.pump();
    await tester.pump();
    var rebuilt = 0;
    for (final element in tester.allElements) {
      final was = before[element];
      if (was == null || !identical(was, element.widget)) rebuilt++;
    }
    return rebuilt;
  }

  Future<DashboardCubits> pumpAt(WidgetTester tester, DashboardSection section) async {
    SharedPreferences.setMockInitialValues({});
    final cubits = DashboardCubits(
      AppRepository(NativeEngineService(), SettingsService()),
      ModelRepository(ModelStorageService()),
      RuntimeRepository(RuntimeStorageService()),
      UpdateRepository(
        UpdateService(client: MockClient((_) async => http.Response('', 503))),
        NotificationService(plugin: FlutterLocalNotificationsPlugin()),
      ),
    );
    addTearDown(cubits.dispose);
    cubits.shell.seed(ShellState(section: section, initializing: false));
    cubits.downloads.seed(DownloadsState(models: modelsAt(0.10)));

    tester.view.physicalSize = const Size(1280, 900);
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
    return cubits;
  }

  testWidgets('a download tick leaves the live screen untouched', (tester) async {
    final cubits = await pumpAt(tester, DashboardSection.live);

    final rebuilt = await rebuiltBy(
      tester,
      () => cubits.downloads.seed(DownloadsState(models: modelsAt(0.11))),
    );

    expect(
      rebuilt,
      0,
      reason: 'the live screen depends on what is installed, not on the bar',
    );
  });

  testWidgets('a download tick redraws the list that shows it', (tester) async {
    final cubits = await pumpAt(tester, DashboardSection.models);

    await rebuiltBy(
      tester,
      () => cubits.downloads.seed(DownloadsState(models: modelsAt(0.11))),
    );

    expect(find.text('11%'), findsOneWidget, reason: 'the bar has to move');
  });

  testWidgets('a recognized phrase leaves the settings screen untouched', (tester) async {
    final cubits = await pumpAt(tester, DashboardSection.settings);

    final rebuilt = await rebuiltBy(
      tester,
      () => cubits.pipeline.seed(
        const LivePipelineState(
          transcript: [
            TranscriptEntry(
              original: 'Take cover.',
              english: 'Take cover.',
              translated: 'В укрытие.',
              latency: Duration(milliseconds: 900),
            ),
          ],
        ),
      ),
    );

    expect(rebuilt, 0, reason: 'only what reads the session redraws');
  });
}

/// The catalogue with one download part of the way through.
List<ModelInstallState> modelsAt(double progress) => [
  for (final model in modelCatalog)
    ModelInstallState(
      model: model,
      progress: model.id == whisperModelId ? progress : null,
    ),
];
