// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../dashboard/cubits/pipeline_cubit.dart';

/// A live session's two controls: rest or wake it, and end it.
///
/// The wide button is the press most likely next — stop while dubbing,
/// resume while paused — and the other waits beside it as an outlined icon,
/// its name in the tooltip. Both fit the slot the start button had.
class SessionButtons extends StatelessWidget {
  const SessionButtons({super.key, required this.paused});

  final bool paused;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (paused) {
      return Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              key: const ValueKey('resumeButton'),
              onPressed: context.read<PipelineCubit>().resume,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(l10n.resumeDubbing),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: l10n.stopHint,
            child: IconButton.outlined(
              key: const ValueKey('stopButton'),
              onPressed: context.read<PipelineCubit>().stop,
              icon: const Icon(Icons.stop_rounded),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Tooltip(
          message: l10n.pauseHint,
          child: IconButton.outlined(
            key: const ValueKey('pauseButton'),
            onPressed: context.read<PipelineCubit>().pause,
            icon: const Icon(Icons.pause_rounded),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            key: const ValueKey('stopButton'),
            onPressed: context.read<PipelineCubit>().stop,
            icon: const Icon(Icons.stop_rounded),
            label: Text(l10n.stopDubbing),
          ),
        ),
      ],
    );
  }
}
