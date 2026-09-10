// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import '../../../data/repositories/app_repository.dart';
import '../../../data/repositories/model_repository.dart';
import '../../../data/repositories/runtime_repository.dart';
import '../../../data/repositories/update_repository.dart';
import '../../../domain/failure.dart';
import '../../../domain/model_selection.dart';
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
    shell.interfaceLanguage = () => settings.settings.interfaceLanguage;
    shell.proxyUrl = () => settings.settings.modelProxyUrl;
  }

  final AppRepository _appRepository;
  final ShellCubit shell;
  late final SettingsCubit settings;
  late final DownloadsCubit downloads;
  late final PipelineCubit pipeline;

  /// What the settings and the installed packages together decided.
  ModelSelection get selection =>
      ModelSelection(models: downloads.state.models, settings: settings.settings);

  Future<void> initialize() async {
    pipeline.listen();
    try {
      final graphics = _appRepository.probeGraphics();
      await Future.wait([settings.load(), pipeline.loadProcesses(), downloads.load()]);
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
    await pipeline.close();
    await downloads.close();
    await settings.close();
    await shell.close();
  }
}
