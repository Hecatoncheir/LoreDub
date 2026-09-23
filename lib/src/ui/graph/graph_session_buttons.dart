// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../common/bloc/session_bloc.dart';
import '../theme.dart';
import 'canvas/pipeline_facts.dart';

/// The running session's own buttons on a scheme's toolbar: resting it and
/// waking it again, where it can rest, and stopping it.
///
/// The cast is rewired on the scheme, and walking to another screen to stop
/// the dubbing first is a walk for nothing. The screen's reading does not
/// rest, so its scheme offers the stop alone.
class GraphSessionButtons extends StatelessWidget {
  const GraphSessionButtons({super.key, required this.facts, required this.rests});

  final PipelineFacts facts;

  /// Whether the session the scheme draws can rest: Эфир's dubbing can.
  final bool rests;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = context.read<SessionBloc>();
    final paused = facts.paused;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rests)
          IconButton(
            key: const ValueKey('graphPause'),
            tooltip: paused ? l10n.resumeDubbing : l10n.pauseHint,
            icon: Icon(
              paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              size: 20,
              color: paused ? context.colors.accent : null,
            ),
            onPressed: () => session.add(paused ? const SessionResumed() : const SessionPaused()),
          ),
        IconButton(
          key: const ValueKey('graphStop'),
          tooltip: l10n.stopDubbing,
          icon: const Icon(Icons.stop_rounded, size: 20),
          onPressed: () => session.add(const SessionStopped()),
        ),
      ],
    );
  }
}
