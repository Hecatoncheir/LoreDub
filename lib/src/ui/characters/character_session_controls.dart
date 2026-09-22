// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/pipeline_state.dart';
import '../../../l10n/app_localizations.dart';
import '../theme.dart';
import '../models/bloc/downloads_bloc.dart';
import '../common/bloc/session_bloc.dart';
import '../shell/bloc/startup_cubit.dart';
import '../common/dashboard_context.dart';
import '../common/language_row.dart';
import '../common/game_picker.dart';
import '../live/starting_spinner.dart';
import '../common/bloc/sources_bloc.dart';
import 'bloc/voice_capture_bloc.dart';

/// Which game to listen to, and whether the session that measures voices is
/// running. Live dubbing holds the same worker, so the two never run at once.
class CharacterSessionControls extends StatelessWidget {
  const CharacterSessionControls({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<StartupCubit, bool>(
    builder: (context, initializing) => BlocBuilder<DownloadsBloc, DownloadsState>(
      buildWhen: whenChanged((downloads) => downloads.installed),
      builder: (context, _) => BlocBuilder<SessionBloc, SessionState>(
        buildWhen: whenChanged(
          (pipeline) => pipeline.running,
        ),
        builder: (context, pipeline) => BlocBuilder<VoiceCaptureBloc, VoiceCaptureState>(
          buildWhen: whenChanged(
            (characters) => (characters.status, characters.cardDoing(CardActivity.recording)),
          ),
          builder: (context, characters) =>
              _build(context, pipeline, characters, initializing: initializing),
        ),
      ),
    ),
  );

  static IconData _sessionIcon(VoiceCaptureState characters) =>
      characters.running ? Icons.stop_rounded : Icons.fiber_manual_record_rounded;

  /// What the line under the button says: why nothing can be recorded, or
  /// how to record.
  static String _hint(AppLocalizations l10n, SessionState pipeline, {required bool canRecord}) {
    if (!canRecord) return l10n.charactersNeedsConverter;
    return pipeline.running ? l10n.snapshotInLive : l10n.charactersHowTo;
  }

  Widget _build(
    BuildContext context,
    SessionState pipeline,
    VoiceCaptureState characters, {
    required bool initializing,
  }) {
    final l10n = AppLocalizations.of(context);
    final canRecord = context.selection.measuresVoices;
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
                    ? const StartingSpinner()
                    : Icon(_sessionIcon(characters)),
                label: Text(
                  characters.running ? l10n.charactersSessionStop : l10n.charactersSessionStart,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _hint(l10n, pipeline, canRecord: canRecord),
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: canRecord ? context.colors.mutedInk : context.colors.warning),
        ),
      ],
    );
  }
}
