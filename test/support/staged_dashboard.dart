// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lore_dub/src/data/repositories/session_repository.dart';
import 'package:lore_dub/src/data/repositories/cast_repository.dart';
import 'package:lore_dub/src/data/repositories/install_repository.dart';
import 'package:lore_dub/src/data/repositories/model_repository.dart';
import 'package:lore_dub/src/data/repositories/runtime_repository.dart';
import 'package:lore_dub/src/data/repositories/settings_repository.dart';
import 'package:lore_dub/src/data/repositories/sources_repository.dart';
import 'package:lore_dub/src/data/repositories/update_repository.dart';
import 'package:lore_dub/src/domain/model_selection.dart';
import 'package:lore_dub/src/domain/session_coordinator.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/cast_bloc.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/downloads_bloc.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/glossary_bloc.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/session_bloc.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/pipeline_facts_bloc.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/pipeline_graph_bloc.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/settings_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/shell_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/sources_bloc.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/transcript_bloc.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/voice_capture_bloc.dart';
import 'package:lore_dub/src/data/repositories/glossary_repository.dart';
import 'package:lore_dub/src/data/repositories/scheme_repository.dart';
import 'package:lore_dub/src/data/repositories/system_repository.dart';
import 'package:lore_dub/src/data/repositories/voice_bank_repository.dart';
import 'package:lore_dub/src/data/services/native_engine_service.dart';
import 'package:lore_dub/src/domain/compute_device.dart';
import 'package:lore_dub/src/domain/model_package.dart';

/// Every screen's state, built by hand for a test to stage and then put on
/// the screen through [provide].
///
/// The application builds them in `DashboardProviders`, each out of the
/// repositories above it, and runs their first reads there. A widget test
/// wants the opposite: states put in place without anything read, and a
/// handle on each to seed and to look at. Nothing here runs a load.
///
/// It goes once the widget tests stage mocked blocs instead (`TODO.md`,
/// stage 4: `bloc_test` and `mocktail`).
class StagedDashboard {
  ///
  /// The repositories a test does not hand over are made over the disk and
  /// the native library as the application's are; one that is handed over
  /// is usually a fake that keeps its files in memory.
  StagedDashboard(
    this.sessionRepository,
    this.settingsRepository,
    ModelRepository modelRepository,
    RuntimeRepository runtimeRepository,
    UpdateRepository updateRepository, {
    NativeEngineService? engine,
    SystemRepository? system,
    VoiceBankRepository? voiceBank,
    SchemeRepository? schemes,
    GlossaryRepository? glossaryRepository,
    CastRepository? cast,
    GlossaryBloc? glossaryBloc,
    CastBloc? castBloc,
    VoiceCaptureBloc? captureBloc,
    DownloadsBloc? downloadsBloc,
  }) {
    final native = engine ?? NativeEngineService();
    this.system = system ?? SystemRepository(native);
    this.voiceBank = voiceBank ?? VoiceBankRepository();
    this.schemes = schemes ?? SchemeRepository();
    this.glossaryRepository = glossaryRepository ?? GlossaryRepository(settingsRepository, native);
    this.cast = cast ?? CastRepository(native);
    installed = InstallRepository(modelRepository, runtimeRepository);
    sourcesRepository = SourcesRepository(this.system);
    shell = ShellCubit(
      updateRepository,
      settingsRepository,
      sessionRepository,
      sessions,
      installed,
      this.system,
    );
    settings = SettingsCubit(
      sessionRepository,
      settingsRepository,
      shell,
      this.voiceBank,
      this.system,
    );
    downloads =
        downloadsBloc ??
        DownloadsBloc(modelRepository, runtimeRepository, installed, settingsRepository, shell);
    sources = SourcesBloc(sourcesRepository, shell);
    pipeline = SessionBloc(
      sessionRepository,
      modelRepository,
      settingsRepository,
      installed,
      sourcesRepository,
      shell,
      sessions,
      this.voiceBank,
    );
    transcript = TranscriptBloc(sessionRepository, sessions, shell);
    cards = castBloc ?? CastBloc(this.cast, shell);
    voices =
        captureBloc ??
        VoiceCaptureBloc(
          sessionRepository,
          modelRepository,
          settingsRepository,
          installed,
          shell,
          sessions,
          this.cast,
        );
    // A screen test hands a mock over: what the screen shows is then what
    // the test says, and what it sends is kept.
    glossary = glossaryBloc ?? GlossaryBloc(this.glossaryRepository, shell);
    graph = PipelineGraphBloc(
      this.schemes,
      settingsRepository,
      this.cast,
      installed,
      sessions,
      shell,
    );
    facts = PipelineFactsBloc(
      settingsRepository,
      installed,
      this.cast,
      sourcesRepository,
      sessions,
    );
  }

  final SessionRepository sessionRepository;
  final SettingsRepository settingsRepository;
  final sessions = SessionCoordinator();
  late final SystemRepository system;
  late final VoiceBankRepository voiceBank;
  late final SchemeRepository schemes;
  late final GlossaryRepository glossaryRepository;
  late final InstallRepository installed;
  late final CastRepository cast;
  late final SourcesRepository sourcesRepository;

  late final ShellCubit shell;
  late final SettingsCubit settings;
  late final DownloadsBloc downloads;
  late final SourcesBloc sources;
  late final SessionBloc pipeline;
  late final TranscriptBloc transcript;

  /// The cards and the packs of the characters screen.
  late final CastBloc cards;

  /// The characters screen's side of the engine.
  late final VoiceCaptureBloc voices;
  late final GlossaryBloc glossary;
  late final PipelineGraphBloc graph;
  late final PipelineFactsBloc facts;

  /// Stages what is on disk and what the machine can run it on, where every
  /// screen reads it: the repository, which the downloads bloc follows an
  /// event later with rows that have nothing arriving. A row with a
  /// download under way is a mock's to stage (`downloadsShowing`).
  void stageInstalled({
    List<ModelInstallState> models = const [],
    ComputeAvailability availability = const ComputeAvailability(),
  }) => installed.seed(
    InstalledParts(
      models: [
        for (final install in models)
          ModelInstallState(model: install.model, installed: install.installed),
      ],
      availability: availability,
    ),
  );

  /// What the settings and the installed packages together decided.
  ModelSelection get selection =>
      ModelSelection(models: downloads.state.models, settings: settings.settings);

  /// [child] under these states and the repositories they were made of,
  /// the way `DashboardProviders` puts the application's.
  Widget provide(Widget child) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider.value(value: sessionRepository),
      RepositoryProvider.value(value: settingsRepository),
      RepositoryProvider.value(value: system),
      RepositoryProvider.value(value: voiceBank),
      RepositoryProvider.value(value: schemes),
      RepositoryProvider.value(value: glossaryRepository),
      RepositoryProvider.value(value: installed),
      RepositoryProvider.value(value: cast),
      RepositoryProvider.value(value: sourcesRepository),
      RepositoryProvider.value(value: sessions),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider.value(value: shell),
        BlocProvider.value(value: settings),
        BlocProvider.value(value: downloads),
        BlocProvider.value(value: sources),
        BlocProvider.value(value: pipeline),
        BlocProvider.value(value: transcript),
        BlocProvider.value(value: cards),
        BlocProvider.value(value: voices),
        BlocProvider.value(value: glossary),
        BlocProvider.value(value: graph),
        BlocProvider.value(value: facts),
      ],
      child: child,
    ),
  );

  Future<void> dispose() async {
    await facts.close();
    await graph.close();
    await glossary.close();
    await voices.close();
    await cards.close();
    await transcript.close();
    await pipeline.close();
    await sources.close();
    await downloads.close();
    await settings.close();
    await shell.close();
    await sessions.dispose();
  }
}
