// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../common/bloc/session_bloc.dart';
import '../failure_messages.dart';
import 'starting_spinner.dart';

/// The one button that starts live dubbing, shows how far the start has got
/// and, pressed again, cancels it or stops the session.
class StartDubbingButton extends StatelessWidget {
  const StartDubbingButton({
    super.key,
    required this.pipeline,
    required this.enabled,
    required this.initializing,
  });

  final SessionState pipeline;

  /// Running, or able to start: either way a press does something.
  final bool enabled;
  final bool initializing;

  String _label(AppLocalizations l10n) {
    if (pipeline.liveStarting) {
      return switch (pipeline.startupProgress) {
        final progress? => l10n.startingProgress((progress * 100).round()),
        null => l10n.startingPlain,
      };
    }
    return pipeline.liveRunning ? l10n.stopDubbing : l10n.startDubbing;
  }

  IconData get _icon => pipeline.liveRunning ? Icons.stop_rounded : Icons.play_arrow_rounded;

  String _tooltip(AppLocalizations l10n) =>
      pipeline.liveStarting && pipeline.startupStage.isNotEmpty
      ? describeStartupStage(l10n, pipeline.startupStage)
      : '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: _tooltip(l10n),
      child: FilledButton.icon(
        onPressed: enabled
            ? () => context.read<SessionBloc>().add(LiveToggled(initializing: initializing))
            : null,
        icon: pipeline.liveStarting
            ? StartingSpinner(progress: pipeline.startupProgress)
            : Icon(_icon),
        label: Text(_label(l10n)),
      ),
    );
  }
}
