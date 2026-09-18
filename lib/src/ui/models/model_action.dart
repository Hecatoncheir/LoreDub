// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/model_package.dart';
import '../../domain/package_transfer.dart';

/// Something a model offers: download, pause, resume, cancel or delete.
///
/// The pieces every model on the Models screen is drawn with — the Whisper
/// bars and the tiles alike — share these, so a download, a pause or a delete
/// looks and behaves the same wherever it is.
class ModelAction {
  const ModelAction({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
}

/// The actions of one package or of a pair downloaded together.
///
/// While anything is in flight the offer is pause or resume, and cancel;
/// otherwise it is download for what is missing and delete for what is
/// there. [locked] keeps the delete of something a live session reads from.
List<ModelAction> modelActions({
  required AppLocalizations l10n,
  required List<ModelInstallState> parts,
  required bool Function(String id) isStopping,
  required bool locked,
  required void Function(ModelInstallState state) onInstall,
  required void Function(ModelInstallState state) onPause,
  required void Function(ModelInstallState state) onCancel,
  required VoidCallback onRemove,
}) {
  final transfer = PackageTransfer(parts);
  if (!transfer.inFlight) {
    return _restingActions(
      l10n,
      transfer,
      locked: locked,
      onInstall: onInstall,
      onRemove: onRemove,
    );
  }
  return _transferActions(
    l10n,
    transfer,
    stopping: parts.any((part) => isStopping(part.model.id)),
    onInstall: onInstall,
    onPause: onPause,
    onCancel: onCancel,
  );
}

/// Nothing in flight: what is missing can be fetched, what is here given
/// back.
List<ModelAction> _restingActions(
  AppLocalizations l10n,
  PackageTransfer transfer, {
  required bool locked,
  required void Function(ModelInstallState state) onInstall,
  required VoidCallback onRemove,
}) => [
  if (transfer.missing.isNotEmpty)
    ModelAction(
      icon: Icons.download_rounded,
      tooltip: l10n.modelDownload,
      onPressed: () => transfer.missing.forEach(onInstall),
    ),
  if (transfer.anyInstalled)
    ModelAction(
      icon: Icons.delete_outline_rounded,
      tooltip: locked ? l10n.modelRemoveInUse : l10n.modelRemove,
      onPressed: locked ? null : onRemove,
    ),
];

/// Something is on its way: it can be held or let go of, and a pair is held
/// and let go of together. A stop already asked for leaves both waiting.
List<ModelAction> _transferActions(
  AppLocalizations l10n,
  PackageTransfer transfer, {
  required bool stopping,
  required void Function(ModelInstallState state) onInstall,
  required void Function(ModelInstallState state) onPause,
  required void Function(ModelInstallState state) onCancel,
}) {
  void holdOrResume() => transfer.running
      ? transfer.downloading.forEach(onPause)
      : transfer.toResume.forEach(onInstall);
  return [
    ModelAction(
      icon: transfer.running ? Icons.pause_rounded : Icons.play_arrow_rounded,
      tooltip: _holdTooltip(l10n, running: transfer.running, stopping: stopping),
      onPressed: stopping ? null : holdOrResume,
    ),
    ModelAction(
      icon: Icons.close_rounded,
      tooltip: l10n.downloadCancel,
      onPressed: stopping ? null : () => transfer.toCancel.forEach(onCancel),
    ),
  ];
}

String _holdTooltip(AppLocalizations l10n, {required bool running, required bool stopping}) {
  if (stopping) return l10n.downloadStopping;
  return running ? l10n.downloadPause : l10n.downloadResume;
}
