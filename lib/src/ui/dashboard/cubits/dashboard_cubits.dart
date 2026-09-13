// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import '../../../data/repositories/app_repository.dart';
import '../../../data/repositories/model_repository.dart';
import '../../../data/repositories/runtime_repository.dart';
import '../../../data/repositories/update_repository.dart';
import '../../../domain/failure.dart';
import '../../../domain/model_selection.dart';
import 'characters_cubit.dart';
import 'downloads_cubit.dart';
import 'pipeline_cubit.dart';
import 'settings_cubit.dart';
import 'shell_cubit.dart';

/// The four parts of the dashboard, wired together.
///
/// They are separate so a widget listens only to the part it draws — a
/// download ticking must not redraw the transcript — but they are created
/// and torn down as one, and the first load runs across all of them.
class DashboardCubits {
  DashboardCubits(
    AppRepository appRepository,
    ModelRepository modelRepository,
    RuntimeRepository runtimeRepository,
    UpdateRepository updateRepository,
  ) : _appRepository = appRepository,
      shell = ShellCubit(updateRepository) {
    settings = SettingsCubit(appRepository, shell);
    downloads = DownloadsCubit(modelRepository, runtimeRepository, settings, shell);
    pipeline = PipelineCubit(appRepository, modelRepository, settings, downloads, shell);
    characters = CharactersCubit(appRepository, modelRepository, settings, downloads, shell);
    shell.interfaceLanguage = () => settings.settings.interfaceLanguage;
    shell.proxyUrl = () => settings.settings.modelProxyUrl;
    // Closing for an update must not leave the game turned down.
    shell.beforeRestart = () async {
      if (pipeline.state.running) await appRepository.stop();
    };
  }

  final AppRepository _appRepository;
  final ShellCubit shell;
  late final SettingsCubit settings;
  late final DownloadsCubit downloads;
  late final PipelineCubit pipeline;
  late final CharactersCubit characters;

  /// The session events reach both the pipeline and the characters screen:
  /// each holds the worker in its turn, and only one of them at a time.
  StreamSubscription<Map<String, Object?>>? _events;

  /// What the settings and the installed packages together decided.
  ModelSelection get selection =>
      ModelSelection(models: downloads.state.models, settings: settings.settings);

  Future<void> initialize() async {
    pipeline.listen();
    _events = _appRepository.events.listen(characters.handleEvent);
    try {
      final graphics = _appRepository.probeGraphics();
      await Future.wait([
        settings.load(),
        pipeline.loadProcesses(),
        downloads.load(),
        characters.load(),
      ]);
      await downloads.refreshAvailability(probe: await graphics);
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
    await _events?.cancel();
    await characters.close();
    await pipeline.close();
    await downloads.close();
    await settings.close();
    await shell.close();
  }
}
