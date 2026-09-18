// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../dashboard/cubits/downloads_cubit.dart';
import '../dashboard/cubits/pipeline_cubit.dart';
import '../dashboard/cubits/settings_cubit.dart';
import '../dashboard/cubits/shell_cubit.dart';
import '../dashboard/dashboard_context.dart';
import 'scene_listen_toggle.dart';

/// Starts the session that only listens for who speaks, or ends it.
///
/// Placing the voices needs the converter and a bank to keep them in; while
/// dubbing or a selection holds the worker, it cannot run at all. Whether it
/// can start reads the settings and the packages on disk as well as the
/// session, so it listens to all of them.
class SceneListenButton extends StatelessWidget {
  const SceneListenButton({super.key});

  @override
  Widget build(BuildContext context) => BlocSelector<ShellCubit, ShellState, bool>(
    selector: (shell) => shell.initializing,
    builder: (context, initializing) => BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, _) => BlocBuilder<DownloadsCubit, DownloadsState>(
        buildWhen: whenChanged((downloads) => downloads.installed),
        builder: (context, _) => BlocBuilder<PipelineCubit, LivePipelineState>(
          buildWhen: whenChanged(
            (pipeline) => (pipeline.status, pipeline.session, pipeline.selectedProcess),
          ),
          builder: (context, pipeline) => SceneListenToggle(
            listening: pipeline.sceneRunning,
            enabled:
                pipeline.sceneRunning ||
                pipeline.canStartScene(context.selection, initializing: initializing),
            initializing: initializing,
          ),
        ),
      ),
    ),
  );
}
