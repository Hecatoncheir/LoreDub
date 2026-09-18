// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'download_controls.dart';

/// A download under way on a card: the bar, how much of it has arrived, and
/// the buttons that pause or cancel it.
class ModelDownloadProgress extends StatelessWidget {
  const ModelDownloadProgress({
    super.key,
    required this.progress,
    required this.paused,
    required this.stopping,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  final double progress;
  final bool paused;
  final bool stopping;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final percent = '${(progress * 100).round()}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        LinearProgressIndicator(value: progress),
        const SizedBox(height: 5),
        Row(
          children: [
            Text(paused ? '$percent · ${AppLocalizations.of(context).downloadPaused}' : percent),
            const Spacer(),
            DownloadControls(
              paused: paused,
              stopping: stopping,
              onPause: onPause,
              onResume: onResume,
              onCancel: onCancel,
            ),
          ],
        ),
      ],
    );
  }
}
