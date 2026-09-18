// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Pause/resume and cancel for a download in flight.
///
/// Kept to two small buttons so it fits the Whisper cards a narrow window
/// falls back to.
class DownloadControls extends StatelessWidget {
  const DownloadControls({
    super.key,
    required this.paused,
    required this.stopping,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  final bool paused;
  final bool stopping;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: stopping
              ? l10n.downloadStopping
              : (paused ? l10n.downloadResume : l10n.downloadPause),
          onPressed: stopping ? null : (paused ? onResume : onPause),
          icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 20),
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          padding: EdgeInsets.zero,
        ),
        IconButton(
          tooltip: l10n.downloadCancel,
          onPressed: stopping ? null : onCancel,
          icon: const Icon(Icons.close_rounded, size: 20),
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }
}
