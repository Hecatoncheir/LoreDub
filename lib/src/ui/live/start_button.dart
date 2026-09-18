// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/pipeline_state.dart';
import '../dashboard/cubits/downloads_cubit.dart';
import '../dashboard/cubits/pipeline_cubit.dart';
import '../dashboard/cubits/shell_cubit.dart';
import '../dashboard/dashboard_context.dart';
import 'session_buttons.dart';
import 'start_dubbing_button.dart';

/// Loading Marian and Silero takes long enough that a plain label would look
/// like a freeze, so the button carries the progress of the startup itself.
class StartButton extends StatelessWidget {
  const StartButton({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<PipelineCubit, LivePipelineState>(
    // The chosen process belongs here too: without it the button stays grey
    // after the player picks one, because nothing else on the screen moved.
    buildWhen: whenChanged(
      (pipeline) => (
        pipeline.status,
        pipeline.session,
        pipeline.startupProgress,
        pipeline.startupStage,
        pipeline.selectedProcess,
      ),
    ),
    // Whether it can start at all depends on the first load having finished
    // and on the packages being there.
    builder: (context, pipeline) => BlocBuilder<ShellCubit, ShellState>(
      builder: (context, shell) => BlocBuilder<DownloadsCubit, DownloadsState>(
        buildWhen: whenChanged((downloads) => downloads.installed),
        // A snapshot session is not this screen's to show: starting here
        // takes the worker over from it.
        builder: (context, _) => pipeline.liveUp
            ? SessionButtons(paused: pipeline.status == PipelineStatus.paused)
            : StartDubbingButton(
                pipeline: pipeline,
                enabled:
                    pipeline.liveRunning ||
                    pipeline.canStart(context.selection, initializing: shell.initializing),
                initializing: shell.initializing,
              ),
      ),
    ),
  );
}
