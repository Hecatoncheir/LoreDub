// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import '../../../data/repositories/app_repository.dart';
import '../../../data/repositories/cast_repository.dart';
import '../../../data/repositories/install_repository.dart';
import '../../../data/repositories/model_repository.dart';
import '../../../data/repositories/runtime_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/update_repository.dart';
import '../../../domain/failure.dart';
import '../../../domain/model_selection.dart';
import '../../../domain/session_coordinator.dart';
import 'characters_cubit.dart';
import 'downloads_cubit.dart';
import 'glossary_cubit.dart';
import 'pipeline_cubit.dart';
import 'pipeline_graph_bloc.dart';
import 'settings_cubit.dart';
import 'shell_cubit.dart';

/// The parts of the dashboard, wired together.
///
/// They are separate so a widget listens only to the part it draws — a
/// download ticking must not redraw the transcript — but they are created
/// and torn down as one, and the first load runs across all of them.
class DashboardCubits {
  DashboardCubits(
    AppRepository appRepository,
    SettingsRepository settingsRepository,
    ModelRepository modelRepository,
    RuntimeRepository runtimeRepository,
    UpdateRepository updateRepository,
  ) : _appRepository = appRepository,
      _settingsRepository = settingsRepository {
    shell = ShellCubit(updateRepository, settingsRepository, appRepository, sessions);
    // One engine holds one session. Each screen registers its own half of
    // that with the coordinator, so neither knows the other and this bag
    // does not hold the rule together.
    settings = SettingsCubit(appRepository, settingsRepository, shell);
    installed = InstallRepository(modelRepository, runtimeRepository);
    downloads = DownloadsCubit(
      modelRepository,
      runtimeRepository,
      installed,
      settingsRepository,
      shell,
    );
    pipeline = PipelineCubit(
      appRepository,
      modelRepository,
      settingsRepository,
      installed,
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
    graph = PipelineGraphBloc(appRepository, settingsRepository, cast, pipeline, shell);
  }

  final AppRepository _appRepository;
  final SettingsRepository _settingsRepository;

  /// What the player configured, published for whoever follows it.
  SettingsRepository get settingsRepository => _settingsRepository;
  late final ShellCubit shell;

  /// Which screen may hold the one worker. Each of the two registers its
  /// own half here, so neither knows the other.
  final sessions = SessionCoordinator();
  late final SettingsCubit settings;
  late final DownloadsCubit downloads;

  /// What is on disk and what the machine can run it on, read once and
  /// told to everyone who cares.
  late final InstallRepository installed;

  /// The player's own cards, which two screens work on.
  late final CastRepository cast = CastRepository(_appRepository);
  late final PipelineCubit pipeline;
  late final CharactersCubit characters;

  /// What the player has written down about their games: the names the
  /// model leaves in Latin script and the lines they have translated
  /// themselves. It answers to no session -- every one of them that
  /// translates is handed the same file.
  late final GlossaryCubit glossary;

  /// The pipeline drawn as nodes. A Bloc rather than a Cubit: the canvas is
  /// worked by sequences of gestures, and each one is an event that can be
  /// replayed and undone.
  late final PipelineGraphBloc graph;

  /// What the settings and the installed packages together decided.
  ModelSelection get selection =>
      ModelSelection(models: downloads.state.models, settings: settings.settings);

  Future<void> initialize() async {
    pipeline.listen();
    try {
      final graphics = _appRepository.probeGraphics();
      // No order between them. Whoever needs the settings first awaits
      // the one read of them -- the glossary does, for the language its
      // built-in packs are written in.
      await Future.wait([
        settings.load(),
        pipeline.loadProcesses(),
        downloads.load(),
        characters.load(),
        glossary.load(),
      ]);
      await downloads.refreshAvailability(probe: await graphics);
      // After the settings and the cast: the canvas is drawn from them, and
      // only the arrangement of the nodes is its own.
      graph.add(const PipelineGraphOpened());
    } catch (exception) {
      shell.report(LoreDubFailure(FailureCode.initializationFailed, detail: '$exception'));
    } finally {
      shell.finishInitializing();
    }
    // Left to run on its own: the dashboard should not wait on GitHub, and
    // a failed check must not look like a failed start.
    unawaited(shell.checkForUpdates(announce: true));
  }

  Future<void> dispose() async {
    await graph.close();
    await glossary.close();
    await characters.close();
    await pipeline.close();
    await downloads.close();
    await settings.close();
    await shell.close();
  }
}
