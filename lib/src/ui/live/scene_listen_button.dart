// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../dashboard/cubits/downloads_bloc.dart';
import '../dashboard/cubits/session_bloc.dart';
import '../dashboard/cubits/settings_bloc.dart';
import '../dashboard/cubits/shell_cubit.dart';
import '../dashboard/dashboard_context.dart';
import 'scene_listen_toggle.dart';
import '../../domain/capture_sources.dart';
import '../../domain/game_process.dart';
import '../dashboard/cubits/sources_bloc.dart';

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
    builder: (context, initializing) => BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, _) => BlocBuilder<DownloadsBloc, DownloadsState>(
        buildWhen: whenChanged((downloads) => downloads.installed),
        builder: (context, _) => BlocBuilder<SessionBloc, SessionState>(
          buildWhen: whenChanged(
            (pipeline) => (pipeline.status, pipeline.session),
          ),
          builder: (context, pipeline) => BlocSelector<SourcesBloc, CaptureSources, GameProcess?>(
            selector: (sources) => sources.selected,
            builder: (context, process) => SceneListenToggle(
              listening: pipeline.sceneRunning,
              enabled:
                  pipeline.sceneRunning ||
                  pipeline.canStartScene(
                    context.selection,
                    initializing: initializing,
                    process: process,
                  ),
              initializing: initializing,
            ),
          ),
        ),
      ),
    ),
  );
}
