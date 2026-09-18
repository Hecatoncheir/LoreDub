// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/model_package.dart';
import '../failure_messages.dart';
import '../model_names.dart';
import '../theme.dart';
import 'model_download_progress.dart';

/// What a [ModelInstallState] is and where it stands: a mark, its name and
/// description, the download under way, and why the last one failed.
class ModelCardDetails extends StatelessWidget {
  const ModelCardDetails({
    super.key,
    required this.state,
    required this.stopping,
    required this.choosable,
    required this.selected,
    required this.onInstall,
    required this.onPause,
    required this.onCancel,
  });

  final ModelInstallState state;
  final bool stopping;

  /// One of a set the player picks between: the mark says which is chosen
  /// rather than whether it is on disk.
  final bool choosable;
  final bool selected;
  final VoidCallback onInstall;
  final VoidCallback onPause;
  final VoidCallback onCancel;

  /// The mark beside the name, as an icon and its colour.
  (IconData, Color) _mark() {
    if (choosable) {
      return selected
          ? (Icons.radio_button_checked, LoreDubPalette.orange)
          : (Icons.radio_button_unchecked, LoreDubPalette.outline);
    }
    return state.installed
        ? (Icons.check_circle_rounded, LoreDubPalette.success)
        : (Icons.memory_rounded, LoreDubPalette.mutedInk);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (mark, markColor) = _mark();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(mark, color: markColor),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                modelTitle(l10n, state.model),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              Text(
                modelDescription(l10n, state.model),
                style: const TextStyle(color: LoreDubPalette.mutedInk),
              ),
              if (state.progress case final progress?)
                ModelDownloadProgress(
                  progress: progress,
                  paused: state.paused,
                  stopping: stopping,
                  onPause: onPause,
                  onResume: onInstall,
                  onCancel: onCancel,
                ),
              if (state.error case final error?) ...[
                const SizedBox(height: 8),
                Text(
                  describeFailure(l10n, error),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
