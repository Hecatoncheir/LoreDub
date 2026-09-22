// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/screen_reading.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/pipeline_state.dart';
import '../../../l10n/app_localizations.dart';
import '../failure_messages.dart';
import '../models/bloc/downloads_bloc.dart';
import '../common/bloc/session_bloc.dart';
import '../settings/bloc/settings_bloc.dart';
import '../shell/bloc/startup_cubit.dart';
import '../common/dashboard_context.dart';
import '../../domain/capture_sources.dart';
import '../../domain/game_process.dart';
import '../common/bloc/sources_bloc.dart';
import '../live/starting_spinner.dart';

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
  Widget build(BuildContext context) => BlocBuilder<SessionBloc, SessionState>(
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
    builder: (context, pipeline) => BlocBuilder<StartupCubit, bool>(
      builder: (context, initializing) => BlocBuilder<DownloadsBloc, DownloadsState>(
        buildWhen: whenChanged((downloads) => downloads.installed),
        builder: (context, _) => BlocBuilder<SettingsBloc, SettingsState>(
          // The game named opens the button for the frame, which reads
          // that game's window.
          builder: (context, _) => BlocSelector<SourcesBloc, CaptureSources, GameProcess?>(
            selector: (sources) => sources.selected,
            builder: (context, process) =>
                _build(context, pipeline, process, initializing: initializing),
          ),
        ),
      ),
    ),
  );

  Widget _build(
    BuildContext context,
    SessionState pipeline,
    GameProcess? process, {
    required bool initializing,
  }) {
    final l10n = AppLocalizations.of(context);
    final own = pipeline.session == PipelineSession.screen && pipeline.screenReading == reading;
    final starting = own && pipeline.status == PipelineStatus.starting;
    final running = own && pipeline.running;
    final progress = pipeline.startupProgress;
    final canStart = pipeline.canStartScreen(
      context.selection,
      initializing: initializing,
      process: process,
      reading: reading,
    );
    return Tooltip(
      message: starting && pipeline.startupStage.isNotEmpty
          ? describeStartupStage(l10n, pipeline.startupStage)
          : '',
      child: FilledButton.icon(
        key: ValueKey('snapshotStart-${reading.name}'),
        onPressed: running || canStart
            ? () => context.read<SessionBloc>().add(
                ScreenToggled(initializing: initializing, reading: reading),
              )
            : null,
        icon: starting ? StartingSpinner(progress: progress) : Icon(_icon(running: running)),
        label: Text(_label(l10n, progress, starting: starting, running: running)),
      ),
    );
  }

  static IconData _icon({required bool running}) =>
      running ? Icons.stop_rounded : Icons.play_arrow_rounded;

  static String _label(
    AppLocalizations l10n,
    double? progress, {
    required bool starting,
    required bool running,
  }) {
    if (starting) {
      return switch (progress) {
        final progress? => l10n.startingProgress((progress * 100).round()),
        null => l10n.startingPlain,
      };
    }
    return running ? l10n.snapshotStop : l10n.snapshotStart;
  }
}
