// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../dashboard/cubits/pipeline_cubit.dart';
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

  final LivePipelineState pipeline;

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
            ? () => context.read<PipelineCubit>().toggle(initializing: initializing)
            : null,
        icon: pipeline.liveStarting
            ? StartingSpinner(progress: pipeline.startupProgress)
            : Icon(pipeline.liveRunning ? Icons.stop_rounded : Icons.play_arrow_rounded),
        label: Text(_label(l10n)),
      ),
    );
  }
}
