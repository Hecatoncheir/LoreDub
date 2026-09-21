// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/pipeline_state.dart';
import '../../../l10n/app_localizations.dart';
import '../theme.dart';
import '../dashboard/cubits/downloads_bloc.dart';
import '../dashboard/cubits/session_bloc.dart';
import '../dashboard/cubits/shell_cubit.dart';
import '../dashboard/dashboard_context.dart';
import '../common/language_row.dart';
import '../common/game_picker.dart';
import '../dashboard/cubits/sources_bloc.dart';
import '../dashboard/cubits/voice_capture_bloc.dart';

/// Which game to listen to, and whether the session that measures voices is
/// running. Live dubbing holds the same worker, so the two never run at once.
class CharacterSessionControls extends StatelessWidget {
  const CharacterSessionControls({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<ShellCubit, ShellState>(
    builder: (context, shell) => BlocBuilder<DownloadsBloc, DownloadsState>(
      buildWhen: whenChanged((downloads) => downloads.installed),
      builder: (context, _) => BlocBuilder<SessionBloc, SessionState>(
        buildWhen: whenChanged(
          (pipeline) => pipeline.running,
        ),
        builder: (context, pipeline) => BlocBuilder<VoiceCaptureBloc, VoiceCaptureState>(
          buildWhen: whenChanged((characters) => (characters.status, characters.recordingId)),
          builder: (context, characters) =>
              _build(context, pipeline, characters, initializing: shell.initializing),
        ),
      ),
    ),
  );

  Widget _build(
    BuildContext context,
    SessionState pipeline,
    VoiceCaptureState characters, {
    required bool initializing,
  }) {
    final l10n = AppLocalizations.of(context);
    final canRecord = context.read<VoiceCaptureBloc>().canRecord;
    final locked = characters.running || pipeline.running;
    final picker = GamePicker(enabled: !locked);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l10n.charactersNote} ${l10n.voicesOnTheGraph}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: picker),
            const SizedBox(width: 16),
            SizedBox(
              width: LanguageRow.actionWidth,
              child: FilledButton.icon(
                key: const ValueKey('charactersSession'),
                onPressed: !canRecord || initializing || pipeline.running
                    ? null
                    : () => context.read<VoiceCaptureBloc>().add(
                        RecordingSessionToggled(
                          initializing: initializing,
                          process: context.read<SourcesBloc>().state.selected,
                        ),
                      ),
                icon: characters.status == PipelineStatus.starting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : Icon(
                        characters.running ? Icons.stop_rounded : Icons.fiber_manual_record_rounded,
                      ),
                label: Text(
                  characters.running ? l10n.charactersSessionStop : l10n.charactersSessionStart,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          !canRecord
              ? l10n.charactersNeedsConverter
              : pipeline.running
              ? l10n.snapshotInLive
              : l10n.charactersHowTo,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: canRecord ? context.colors.mutedInk : context.colors.warning),
        ),
      ],
    );
  }
}
