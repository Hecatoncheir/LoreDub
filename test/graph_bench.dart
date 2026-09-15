// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// A stopwatch on the graph screen, run by hand rather than by CI: it has no
// `_test` suffix, so a plain `flutter test` passes it by.
//
//   flutter test test/graph_bench.dart
//
// What it times is the Dart side of a frame — build, layout and paint into a
// recording canvas — with no GPU behind it, so the numbers are for comparing
// one build of this file with another rather than for quoting.

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
import 'package:lore_dub/src/domain/character.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/pipeline_graph.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/characters_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/dashboard_cubits.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/downloads_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/pipeline_graph_bloc.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/shell_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/dashboard_view.dart';
import 'package:lore_dub/src/ui/theme.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cards = 24;

  List<Character> cast() => [
    for (var index = 0; index < cards; index++)
      Character(
        id: 'card$index',
        name: 'Персонаж $index',
        vector: const [0.2, 0.4],
        seconds: 2.5,
      ),
  ];

  Future<DashboardCubits> pumpGraph(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const {});
    tester.view.physicalSize = const Size(1500, 950);
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
    cubits.downloads.seed(
      DownloadsState(
        models: [
          for (final model in modelCatalog) ModelInstallState(model: model, installed: true),
        ],
      ),
    );
    cubits.characters.seed(CharactersState(loading: false, characters: cast()));
    cubits.graph.seed(
      PipelineGraphState(
        loading: false,
        layout: PipelineLayout.drawing([for (final card in cast()) card.id]),
      ),
    );
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

  /// Runs [frames] of [step] and reports the microseconds one frame cost.
  Future<double> time(WidgetTester tester, int frames, Future<void> Function() step) async {
    // A warm-up pass, so the first frame's lazy work is not in the number.
    for (var frame = 0; frame < 5; frame++) {
      await step();
    }
    final watch = Stopwatch()..start();
    for (var frame = 0; frame < frames; frame++) {
      await step();
    }
    watch.stop();
    return watch.elapsedMicroseconds / frames;
  }

  testWidgets('a scheme of $cards cards', (tester) async {
    final cubits = await pumpGraph(tester);

    final dragging = await time(tester, 60, () async {
      cubits.graph.add(const PipelineNodeMoved(PipelineNodeIds.recognition, 1, 1));
      await tester.pump(const Duration(milliseconds: 16));
    });

    final panning = await time(tester, 60, () async {
      cubits.graph.add(const PipelineViewPanned(1, 1));
      await tester.pump(const Duration(milliseconds: 16));
    });

    final still = await time(tester, 60, () async {
      await tester.pump(const Duration(milliseconds: 16));
    });

    // The pure part of a drag frame: the graph rebuilt from the settings,
    // the cast and the arrangement, with no widgets in it at all.
    final layout = cubits.graph.state.layout;
    final characters = cast();
    final watch = Stopwatch()..start();
    for (var pass = 0; pass < 200; pass++) {
      buildPipelineGraph(
        settings: const AppSettings(),
        characters: characters,
        layout: layout,
      );
    }
    watch.stop();
    final model = watch.elapsedMicroseconds / 200;

    debugPrint(
      'BENCH drag=${dragging.round()}us pan=${panning.round()}us '
      'idle=${still.round()}us model=${model.round()}us',
    );
  });
}
