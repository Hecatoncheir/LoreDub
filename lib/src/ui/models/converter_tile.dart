// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/model_package.dart';
import '../compute_names.dart';
import '../model_names.dart';
import 'model_removal.dart';
import 'model_tile_part.dart';
import 'model_action.dart';
import 'model_tile.dart';
import 'download_progress_line.dart';

/// The OpenVoice converter: one package, in use whenever the original voice
/// is on.
class ConverterTile extends StatelessWidget {
  const ConverterTile({
    super.key,
    required this.state,
    required this.inUse,
    required this.running,
    required this.isStopping,
    required this.onInstall,
    required this.onPause,
    required this.onCancel,
    required this.onRemove,
  });

  final ModelInstallState state;

  /// The original voice is on, so this is the converter the pipeline uses.
  final bool inUse;
  final bool running;
  final bool Function(String id) isStopping;
  final void Function(ModelInstallState state) onInstall;
  final void Function(ModelInstallState state) onPause;
  final void Function(ModelInstallState state) onCancel;
  final void Function(ModelInstallState state) onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final model = state.model;
    final progress = state.progress;
    return ModelTile(
      title: 'OpenVoice ${model.version ?? ''}'.trim(),
      parts: [
        ModelTilePart(
          label: l10n.modelPartConverter,
          bytes: model.downloadBytes,
          installed: state.installed,
        ),
      ],
      progress: progress,
      paused: state.paused,
      installed: state.installed,
      inUse: inUse && state.installed && progress == null,
      marked: inUse,
      tooltip: [
        modelTitle(l10n, model),
        modelDescription(l10n, model),
        if (progress != null)
          downloadProgressLine(l10n, progress, model.downloadBytes)
        else
          inUse ? l10n.converterHintInUse : l10n.converterHintIdle,
      ].join('\n'),
      onTap: null,
      actions: modelActions(
        l10n: l10n,
        parts: [state],
        isStopping: isStopping,
        locked: running && inUse,
        onInstall: onInstall,
        onPause: onPause,
        onCancel: onCancel,
        onRemove: () async {
          final confirmed = await confirmModelRemoval(
            context,
            title: l10n.modelRemoveTitle,
            message: l10n.modelRemoveMessage(
              modelTitle(l10n, model),
              formatPackageSize(l10n, model.downloadBytes),
            ),
          );
          if (confirmed) onRemove(state);
        },
      ),
    );
  }
}
