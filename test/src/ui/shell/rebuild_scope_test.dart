// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lore_dub/l10n/app_localizations.dart';
import 'package:lore_dub/src/data/repositories/settings_repository.dart';
import 'package:lore_dub/src/data/repositories/session_repository.dart';
import 'package:lore_dub/src/data/repositories/model_repository.dart';
import 'package:lore_dub/src/data/repositories/runtime_repository.dart';
import 'package:lore_dub/src/data/repositories/update_repository.dart';
import 'package:lore_dub/src/data/services/model_catalog.dart';
import 'package:lore_dub/src/data/services/model_storage_service.dart';
import 'package:lore_dub/src/data/services/notification_service.dart';
import 'package:lore_dub/src/data/services/runtime_storage_service.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/data/services/update_service.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart';
import 'package:lore_dub/src/domain/spoken_language.dart';

import '../../../support/staged_dashboard.dart';

import 'package:lore_dub/src/ui/models/bloc/downloads_bloc.dart';
import 'package:lore_dub/src/ui/shell/bloc/navigation_cubit.dart';
import 'package:lore_dub/src/ui/shell/dashboard_scaffold.dart';
import 'package:lore_dub/src/ui/theme.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lore_dub/src/ui/common/bloc/transcript_bloc.dart';

import '../../../support/mock_blocs.dart';
import '../../../support/fakes/memory_native.dart';

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

  /// The downloads of the screen under test, which a tick is sent down.
  late StreamController<DownloadsState> ticks;

  /// One tick of a download under way.
  void tick() => ticks.add(DownloadsState(models: modelsAt(0.11)));

  Future<StagedDashboard> pumpAt(
    WidgetTester tester,
    DashboardSection section, {
    LiveView liveView = LiveView.dubbing,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final cubits = StagedDashboard(
      SessionRepository(memoryEngine()),
      SettingsRepository(SettingsService()),
      ModelRepository(ModelStorageService()),
      RuntimeRepository(RuntimeStorageService()),
      UpdateRepository(
        UpdateService(
          client: MockClient((_) async => http.Response('', 503)),
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
      // A download is under way on a mock, whose ticks the test sends.
      downloadsBloc: downloadsShowing(
        DownloadsState(models: modelsAt(0.10)),
        then: (ticks = StreamController<DownloadsState>.broadcast()).stream,
      ),
    );
    addTearDown(cubits.dispose);
    addTearDown(ticks.close);
    cubits.stageSection(section, liveView);
    cubits.stageInstalled(models: modelsAt(0.10));

    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale(defaultInterfaceLanguage),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: cubits.provide(const DashboardScaffold()),
      ),
    );
    await tester.pump();
    return cubits;
  }

  testWidgets('a download tick leaves the live screen untouched', (tester) async {
    await pumpAt(tester, DashboardSection.live);

    final rebuilt = await rebuiltBy(
      tester,
      tick,
    );

    expect(
      rebuilt,
      0,
      reason: 'the live screen depends on what is installed, not on the bar',
    );
  });

  testWidgets('a download tick redraws the list that shows it', (tester) async {
    await pumpAt(tester, DashboardSection.models);

    await rebuiltBy(
      tester,
      tick,
    );

    expect(find.text('11%'), findsOneWidget, reason: 'the bar has to move');
  });

  testWidgets('a download tick leaves the pipeline scheme untouched', (tester) async {
    final cubits = await pumpAt(
      tester,
      DashboardSection.live,
      liveView: LiveView.scheme,
    );
    cubits.stageScheme();
    // The canvas fits the scheme into the window after the frame that
    // measured it, so the screen settles a few frames after it is seeded.
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump();
    }

    final rebuilt = await rebuiltBy(
      tester,
      tick,
    );

    expect(
      rebuilt,
      0,
      reason: 'the scheme draws what is installed, not how far a download got',
    );
  });

  testWidgets('a recognized phrase leaves the settings screen untouched', (tester) async {
    final cubits = await pumpAt(tester, DashboardSection.settings);

    final rebuilt = await rebuiltBy(
      tester,
      () => cubits.stageLists(
        const TranscriptState(
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

    expect(rebuilt, 0, reason: 'only what reads the transcript redraws');
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
