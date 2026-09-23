// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// What every screen test of the whole dashboard is staged and pumped with:
// the blocs built by hand over repositories that answer from memory, a
// state put on the screen without the load that would produce it, and the
// scrollers the pages are driven through.

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lore_dub/l10n/app_localizations.dart';
import 'package:lore_dub/src/app.dart';
import 'package:lore_dub/src/data/repositories/cast_repository.dart';
import 'package:lore_dub/src/data/repositories/model_repository.dart';
import 'package:lore_dub/src/data/repositories/runtime_repository.dart';
import 'package:lore_dub/src/data/repositories/session_repository.dart';
import 'package:lore_dub/src/data/repositories/settings_repository.dart';
import 'package:lore_dub/src/data/repositories/update_repository.dart';
import 'package:lore_dub/src/data/repositories/voice_bank_repository.dart';
import 'package:lore_dub/src/data/services/model_catalog.dart';
import 'package:lore_dub/src/data/services/model_storage_service.dart';
import 'package:lore_dub/src/data/services/notification_service.dart';
import 'package:lore_dub/src/data/services/runtime_storage_service.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/data/services/update_service.dart';
import 'package:lore_dub/src/domain/app_release.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/compute_device.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart'
    show PipelineStatus, SceneSpeaker, TranscriptEntry;
import 'package:lore_dub/src/domain/runtime_package.dart';
import 'package:lore_dub/src/domain/spoken_language.dart';
import 'package:lore_dub/src/ui/characters/bloc/cast_bloc.dart';
import 'package:lore_dub/src/ui/models/bloc/downloads_bloc.dart';
import 'package:lore_dub/src/ui/glossary/bloc/glossary_bloc.dart';
import 'package:lore_dub/src/ui/shell/bloc/navigation_cubit.dart';
import 'package:lore_dub/src/ui/common/bloc/session_bloc.dart';
import 'package:lore_dub/src/ui/common/bloc/transcript_bloc.dart';
import 'package:lore_dub/src/ui/shell/bloc/update_bloc.dart';
import 'package:lore_dub/src/ui/characters/bloc/voice_capture_bloc.dart';
import 'package:lore_dub/src/ui/shell/dashboard_scaffold.dart';
import 'package:lore_dub/src/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'memory_cast.dart';
import 'staged_dashboard.dart';
import 'fakes/memory_native.dart';

StagedDashboard buildCubits({
  RuntimeRepository? runtimes,
  GlossaryBloc? glossary,
  CastBloc? cast,
  VoiceCaptureBloc? capture,
  DownloadsBloc? downloads,
  VoiceBankRepository? voiceBank,
  SessionBloc? session,
  TranscriptBloc? transcript,
  UpdateBloc? updates,
}) {
  SharedPreferences.setMockInitialValues({});
  final cubits = StagedDashboard(
    SessionRepository(memoryEngine()),
    SettingsRepository(SettingsService()),
    ModelRepository(ModelStorageService()),
    runtimes ?? RuntimeRepository(RuntimeStorageService()),
    UpdateRepository(UpdateService(client: _offline), NotificationService(plugin: _silent)),
    glossaryBloc: glossary,
    // The cards in memory: a real bloc editing them wrote a real file,
    // which does not answer inside the test's fake time, and its close
    // waited for the write for ever.
    cast: CastRepository(memoryEngine(), MemoryCharacters()),
    castBloc: cast,
    captureBloc: capture,
    downloadsBloc: downloads,
    voiceBank: voiceBank,
    sessionBloc: session,
    transcriptBloc: transcript,
    updateBloc: updates,
  );
  addTearDown(cubits.dispose);
  return cubits;
}

/// Puts a state on the screen without running the load that would produce
/// it. The first load never finishes inside a widget test — it reads the
/// disk — so what the widgets read is seeded instead.
StagedDashboard stage(
  StagedDashboard cubits, {
  DashboardSection section = DashboardSection.live,
  LiveView liveView = LiveView.dubbing,
  ScreenView screenView = ScreenView.reading,
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
  cubits.stageSection(section, liveView, screenView);
  cubits.stageUpdates(updates);
  if (settings != null) cubits.settingsRepository.seed(settings);
  // What is on disk, which every screen reads; a row with a download
  // under way is staged over a mock instead (`downloadsShowing`).
  if (models != null || runtimes != null || availability != null) {
    final machine = availability ?? const ComputeAvailability();
    cubits.stageInstalled(
      models: models ?? const [],
      availability: machine.copyWith(
        installedRuntimes: {
          ...machine.installedRuntimes,
          for (final runtime in runtimes ?? const <RuntimeInstallState>[])
            if (runtime.installed) runtime.package.id,
        },
      ),
    );
  }
  cubits.stageSession(
    SessionState(
      status: status,
      detectedLanguage: detectedLanguage,
      startupProgress: startupProgress,
      startupStage: startupStage,
    ),
  );
  // After the session: its start empties the lists, and what is staged
  // here is what a running one has said.
  cubits.stageLists(TranscriptState(transcript: transcript, speakers: speakers));
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
Future<void> pumpDashboard(WidgetTester tester, StagedDashboard cubits, Size size) async {
  tester.view.physicalSize = size;
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
}

/// One page's own list. The navigation beside it scrolls too, so the first
/// scrollable in the tree is not the one a page's test means. Inside the
/// list, the first is: a card may hold a scroller of its own -- the
/// stage-by-device table scrolls sideways -- and the list's is above them.
Finder pageScroller(String key) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Scrollable)).first;

Finder settingsScroller() => pageScroller('settingsList');

Finder liveScroller() => pageScroller('liveList');

/// The transcript stands under the dubbing's own settings now, so it is
/// scrolled to rather than found where the page opens.
Future<void> showTranscript(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('РАСШИФРОВКА'),
    300,
    scrollable: liveScroller(),
  );
  await tester.pumpAndSettle();
}

Finder modelsScroller() => pageScroller('modelsList');

Finder glossaryScroller() => pageScroller('glossaryList');

Future<void> pumpLoreDub(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(LoreDubBootstrap(native: MemoryNative()));
  await tester.pump();
}

/// The tests never reach the network: the update check is answered with a
/// refusal, which the interface renders as "could not check".
final http.Client _offline = MockClient(
  (_) async => http.Response('offline', 503),
);

/// A notification plugin that does nothing, so no toast escapes a test run.
final FlutterLocalNotificationsPlugin _silent = FlutterLocalNotificationsPlugin();
