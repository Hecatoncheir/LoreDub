// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lore_dub/src/data/repositories/app_repository.dart';
import 'package:lore_dub/src/data/repositories/cast_repository.dart';
import 'package:lore_dub/src/data/repositories/install_repository.dart';
import 'package:lore_dub/src/data/repositories/model_repository.dart';
import 'package:lore_dub/src/data/repositories/runtime_repository.dart';
import 'package:lore_dub/src/data/repositories/settings_repository.dart';
import 'package:lore_dub/src/data/repositories/sources_repository.dart';
import 'package:lore_dub/src/data/repositories/update_repository.dart';
import 'package:lore_dub/src/domain/model_selection.dart';
import 'package:lore_dub/src/domain/session_coordinator.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/characters_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/downloads_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/glossary_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/pipeline_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/pipeline_facts_bloc.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/pipeline_graph_bloc.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/settings_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/shell_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/sources_bloc.dart';

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
  StagedDashboard(
    this.appRepository,
    this.settingsRepository,
    ModelRepository modelRepository,
    RuntimeRepository runtimeRepository,
    UpdateRepository updateRepository,
  ) {
    installed = InstallRepository(modelRepository, runtimeRepository);
    cast = CastRepository(appRepository);
    sourcesRepository = SourcesRepository(appRepository);
    shell = ShellCubit(updateRepository, settingsRepository, appRepository, sessions, installed);
    settings = SettingsCubit(appRepository, settingsRepository, shell);
    downloads = DownloadsCubit(
      modelRepository,
      runtimeRepository,
      installed,
      settingsRepository,
      shell,
    );
    sources = SourcesBloc(sourcesRepository, shell);
    pipeline = PipelineCubit(
      appRepository,
      modelRepository,
      settingsRepository,
      installed,
      sourcesRepository,
      shell,
      sessions,
    );
    characters = CharactersCubit(
      appRepository,
      modelRepository,
      settingsRepository,
      installed,
      shell,
      sessions,
      cast,
    );
    glossary = GlossaryCubit(appRepository, shell);
    graph = PipelineGraphBloc(appRepository, settingsRepository, cast, installed, sessions, shell);
    facts = PipelineFactsBloc(settingsRepository, installed, cast, sourcesRepository, sessions);
  }

  final AppRepository appRepository;
  final SettingsRepository settingsRepository;
  final sessions = SessionCoordinator();
  late final InstallRepository installed;
  late final CastRepository cast;
  late final SourcesRepository sourcesRepository;

  late final ShellCubit shell;
  late final SettingsCubit settings;
  late final DownloadsCubit downloads;
  late final SourcesBloc sources;
  late final PipelineCubit pipeline;
  late final CharactersCubit characters;
  late final GlossaryCubit glossary;
  late final PipelineGraphBloc graph;
  late final PipelineFactsBloc facts;

  /// What the settings and the installed packages together decided.
  ModelSelection get selection =>
      ModelSelection(models: downloads.state.models, settings: settings.settings);

  /// [child] under these states and the repositories they were made of,
  /// the way `DashboardProviders` puts the application's.
  Widget provide(Widget child) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider.value(value: appRepository),
      RepositoryProvider.value(value: settingsRepository),
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
        BlocProvider.value(value: characters),
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
    await characters.close();
    await pipeline.close();
    await sources.close();
    await downloads.close();
    await settings.close();
    await shell.close();
    await sessions.dispose();
  }
}
