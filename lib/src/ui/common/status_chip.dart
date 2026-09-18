// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../domain/pipeline_state.dart';
import '../../../l10n/app_localizations.dart';
import '../failure_messages.dart';
import '../theme.dart';

/// Where the session stands, as a coloured dot and a word beside the
/// screen title.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.stage = '', this.snapshot = false});

  final PipelineStatus status;

  /// What the startup is doing right now, shown instead of a bare "Запуск…".
  final String stage;

  /// The snapshot session listens for nothing: it waits for a selection.
  final bool snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, color) = switch (status) {
      PipelineStatus.idle => (l10n.statusIdle, LoreDubPalette.mutedInk),
      PipelineStatus.starting => (
        stage.isEmpty ? l10n.statusStarting : describeStartupStage(l10n, stage),
        LoreDubPalette.warning,
      ),
      PipelineStatus.listening => (
        snapshot ? l10n.statusSnapshotReady : l10n.statusListening,
        LoreDubPalette.success,
      ),
      PipelineStatus.paused => (l10n.statusPaused, LoreDubPalette.warning),
      PipelineStatus.stopping => (l10n.statusStopping, LoreDubPalette.warning),
      PipelineStatus.error => (l10n.statusError, LoreDubPalette.error),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
