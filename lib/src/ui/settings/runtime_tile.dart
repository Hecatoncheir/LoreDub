// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/runtime_package.dart';
import '../compute_names.dart';
import '../models/model_tile.dart';
import '../models/model_removal.dart';
import '../models/model_action.dart';
import '../models/model_tile_part.dart';

/// A GPU runtime as a tile, the way the models are drawn: fetched, paused,
/// resumed, cancelled and given back from its own buttons.
class RuntimeTile extends StatelessWidget {
  const RuntimeTile({
    super.key,
    required this.state,
    required this.inUse,
    required this.running,
    required this.stopping,
    required this.onInstall,
    required this.onPause,
    required this.onCancel,
    required this.onRemove,
  });

  final RuntimeInstallState state;

  /// A stage runs on this package right now.
  final bool inUse;

  /// Dubbing is on: nothing is fetched or given back under a live session.
  final bool running;

  /// A stop has been asked for and the download has not noticed yet.
  final bool stopping;

  /// Starts the download, or resumes a paused one.
  final VoidCallback onInstall;
  final VoidCallback onPause;
  final VoidCallback onCancel;

  /// Gives the package back; asked only once the reader has confirmed.
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final package = state.package;
    final size = formatPackageSize(l10n, package.approximateBytes);
    return ModelTile(
      title: runtimeName(l10n, package.id),
      parts: [
        ModelTilePart(
          label: runtimeServes(l10n, package.id),
          bytes: package.approximateBytes,
          installed: state.installed,
        ),
      ],
      progress: state.progress,
      paused: state.paused,
      installed: state.installed,
      inUse: inUse && state.installed && state.progress == null,
      marked: inUse && state.installed,
      tooltip: '${runtimeName(l10n, package.id)}\n${_hint(l10n, size)}',
      onTap: null,
      actions: _actions(context, l10n, size),
    );
  }

  /// What the tile offers right now: a download on its way can be held or
  /// stopped, one that is not here can be fetched, and one that is here can
  /// be given back.
  List<ModelAction> _actions(BuildContext context, AppLocalizations l10n, String size) {
    if (state.progress != null) return _whileDownloading(l10n);
    if (!state.installed) {
      return [
        ModelAction(
          icon: Icons.download_rounded,
          tooltip: l10n.modelDownload,
          onPressed: running ? null : onInstall,
        ),
      ];
    }
    return [
      ModelAction(
        icon: Icons.delete_outline_rounded,
        tooltip: running ? l10n.runtimeRemoveLocked : l10n.computeRuntimeRemove,
        onPressed: running ? null : () => _askThenRemove(context, l10n, size),
      ),
    ];
  }

  List<ModelAction> _whileDownloading(AppLocalizations l10n) => [
    // pip runs to the end or not at all, so only a cancel is offered.
    if (state.pausable)
      ModelAction(
        icon: state.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
        tooltip: _holdTooltip(l10n),
        onPressed: stopping ? null : (state.paused ? onInstall : onPause),
      ),
    ModelAction(
      icon: Icons.close_rounded,
      tooltip: state.pausable ? l10n.downloadCancel : l10n.downloadCancelNotResumable,
      onPressed: stopping ? null : onCancel,
    ),
  ];

  String _holdTooltip(AppLocalizations l10n) {
    if (stopping) return l10n.downloadStopping;
    return state.paused ? l10n.downloadResume : l10n.downloadPause;
  }

  Future<void> _askThenRemove(BuildContext context, AppLocalizations l10n, String size) async {
    final confirmed = await confirmModelRemoval(
      context,
      title: l10n.computeRuntimeRemoveTitle,
      message: l10n.computeRuntimeRemoveMessage(size),
      confirmLabel: l10n.computeRuntimeRemoveConfirm,
    );
    if (confirmed) onRemove();
  }

  /// The second line of the tooltip: how far the download is, or what the
  /// package is doing for this machine.
  String _hint(AppLocalizations l10n, String size) {
    if (state.progress case final progress?) {
      return l10n.whisperDownloadProgress(
        (progress * 100).round(),
        formatPackageSize(l10n, (state.package.approximateBytes * progress).round()),
        size,
      );
    }
    if (!state.installed) return l10n.computeRuntimeMissing(size);
    return inUse ? l10n.runtimeHintInUse : l10n.runtimeHintIdle;
  }
}
