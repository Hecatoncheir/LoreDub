// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/screen_reading.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/pipeline_state.dart';
import '../../../l10n/app_localizations.dart';
import '../failure_messages.dart';
import '../dashboard/cubits/downloads_cubit.dart';
import '../dashboard/cubits/pipeline_cubit.dart';
import '../dashboard/cubits/settings_cubit.dart';
import '../dashboard/cubits/shell_cubit.dart';
import '../dashboard/dashboard_context.dart';

/// Starts and ends a session of this page, reading what [reading] says.
///
/// Each of the three areas carries one. The button of the reading that is
/// running stops it; another one stops it and starts its own. While live
/// dubbing runs, that session answers the snapshot key, so there is
/// nothing here to start.
class SnapshotStartButton extends StatelessWidget {
  const SnapshotStartButton({super.key, this.reading = ScreenReading.both});

  final ScreenReading reading;

  @override
  Widget build(BuildContext context) => BlocBuilder<PipelineCubit, LivePipelineState>(
    buildWhen: whenChanged(
      (pipeline) => (
        pipeline.status,
        pipeline.session,
        pipeline.startupProgress,
        pipeline.startupStage,
      ),
    ),
    // Whether it can start depends on the first load, the packages and the
    // key being bound.
    builder: (context, pipeline) => BlocBuilder<ShellCubit, ShellState>(
      builder: (context, shell) => BlocBuilder<DownloadsCubit, DownloadsState>(
        buildWhen: whenChanged((downloads) => downloads.installed),
        builder: (context, _) => BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, _) => _build(context, pipeline, initializing: shell.initializing),
        ),
      ),
    ),
  );

  Widget _build(BuildContext context, LivePipelineState pipeline, {required bool initializing}) {
    final l10n = AppLocalizations.of(context);
    final own = pipeline.session == PipelineSession.screen && pipeline.screenReading == reading;
    final starting = own && pipeline.status == PipelineStatus.starting;
    final running = own && pipeline.running;
    final progress = pipeline.startupProgress;
    final canStart = pipeline.canStartScreen(
      context.selection,
      initializing: initializing,
      reading: reading,
    );
    return Tooltip(
      message: starting && pipeline.startupStage.isNotEmpty
          ? describeStartupStage(l10n, pipeline.startupStage)
          : '',
      child: FilledButton.icon(
        key: ValueKey('snapshotStart-${reading.name}'),
        onPressed: running || canStart
            ? () => context.read<PipelineCubit>().toggleScreenText(
                initializing: initializing,
                reading: reading,
              )
            : null,
        icon: starting
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2.4,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : Icon(running ? Icons.stop_rounded : Icons.play_arrow_rounded),
        label: Text(
          starting
              ? (progress == null
                    ? l10n.startingPlain
                    : l10n.startingProgress((progress * 100).round()))
              : running
              ? l10n.snapshotStop
              : l10n.snapshotStart,
        ),
      ),
    );
  }
}
