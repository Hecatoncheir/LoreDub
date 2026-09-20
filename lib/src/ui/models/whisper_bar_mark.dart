// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/model_package.dart';
import '../theme.dart';
import 'model_progress_dial.dart';

/// What stands over a Whisper bar's name: the dial of its download, with a
/// word when it is paused, or the cloud saying whether it is on disk.
class WhisperBarMark extends StatelessWidget {
  const WhisperBarMark({
    super.key,
    required this.state,
    required this.inUse,
    required this.roomy,
    required this.dialSize,
  });

  final ModelInstallState state;
  final bool inUse;
  final bool roomy;
  final double dialSize;

  @override
  Widget build(BuildContext context) {
    final progress = state.progress;
    if (progress == null) {
      return Icon(
        state.installed ? Icons.cloud_done_outlined : Icons.cloud_download_outlined,
        size: roomy ? 34 : 24,
        color: inUse || !state.installed ? context.colors.accent : context.colors.ink,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ModelProgressDial(
          key: ValueKey('whisperDial-${state.model.id}'),
          progress: progress,
          paused: state.paused,
          size: dialSize,
        ),
        if (state.paused) ...[
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context).downloadPaused,
            style: context.textStyles.monoCaption.copyWith(color: context.colors.accent),
          ),
        ],
      ],
    );
  }
}
