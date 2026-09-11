// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/runtime_package.dart';
import '../compute_names.dart';
import '../theme.dart';
import 'model_tiles.dart';
import 'model_visuals.dart';

/// What one cell of the stage-by-device table says about its pair.
enum BackendCellState {
  /// The stage runs here.
  selected,

  /// It could, at a click.
  ready,

  /// The card is there but the package for it is not: a click fetches it.
  needsRuntime,

  /// That package is on its way.
  downloading,

  /// No card or driver for this backend on this machine.
  noHardware,

  /// The stage has no build for this backend at all.
  unsupported,
}

/// One stage on one device, drawn in the models' vocabulary: dark with an
/// orange edge where the stage runs, light where it could, a download cloud
/// where a package is missing, a fill while it arrives, and faded where the
/// machine or the stage rules it out — with the reason in the tooltip.
class BackendCell extends StatelessWidget {
  const BackendCell({
    super.key,
    required this.label,
    required this.state,
    required this.tooltip,
    this.detail,
    this.progress,
    this.onTap,
  });

  final String label;
  final BackendCellState state;
  final String tooltip;

  /// A size to fetch, or how far the fetch got.
  final String? detail;
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final selected = state == BackendCellState.selected;
    final loading = state == BackendCellState.downloading;
    final off = state == BackendCellState.noHardware || state == BackendCellState.unsupported;
    final ink = selected
        ? LoreDubPalette.raised
        : loading
        ? LoreDubPalette.orange
        : off
        ? LoreDubPalette.mutedInk.withValues(alpha: 0.7)
        : LoreDubPalette.ink;
    final icon = switch (state) {
      BackendCellState.selected => Icons.check_rounded,
      BackendCellState.needsRuntime => Icons.cloud_download_outlined,
      BackendCellState.noHardware => Icons.block_rounded,
      BackendCellState.unsupported => Icons.remove_rounded,
      BackendCellState.ready || BackendCellState.downloading => null,
    };
    final iconColour = selected || state == BackendCellState.needsRuntime
        ? LoreDubPalette.orange
        : ink;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: HoverGrow(
        alignment: Alignment.center,
        scale: onTap == null ? 1 : 1.04,
        builder: (context, hovered) => Semantics(
          button: onTap != null,
          selected: selected,
          label: label,
          child: Material(
            color: selected
                ? LoreDubPalette.graphite
                : off
                ? Colors.transparent
                : LoreDubPalette.panel,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              side: BorderSide(
                color: selected || loading
                    ? LoreDubPalette.orange
                    : hovered && onTap != null
                    ? LoreDubPalette.ink
                    : LoreDubPalette.outline.withValues(alpha: off ? 0.5 : 1),
                width: selected || loading ? 2 : 1,
              ),
            ),
            child: InkWell(
              onTap: onTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (progress case final value?)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedFractionallySizedBox(
                        duration: const Duration(milliseconds: 300),
                        heightFactor: value.clamp(0.0, 1.0),
                        widthFactor: 1,
                        child: const ColoredBox(color: LoreDubPalette.graphite),
                      ),
                    ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (icon != null) ...[
                              Icon(icon, size: 16, color: iconColour),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              label,
                              style: TextStyle(
                                fontFamily: LoreDubFonts.mono,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ink,
                              ),
                            ),
                            if (detail case final text?) ...[
                              const SizedBox(width: 6),
                              Text(
                                text,
                                style: TextStyle(
                                  fontFamily: LoreDubFonts.mono,
                                  fontSize: 11,
                                  color: ink.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
    final size = formatPackageSize(package.approximateBytes);
    final title = runtimeName(l10n, package.id);
    final progress = state.progress;
    final List<ModelAction> actions;
    if (progress != null) {
      actions = [
        // pip runs to the end or not at all, so only a cancel is offered.
        if (state.pausable)
          ModelAction(
            icon: state.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            tooltip: stopping
                ? l10n.downloadStopping
                : state.paused
                ? l10n.downloadResume
                : l10n.downloadPause,
            onPressed: stopping ? null : (state.paused ? onInstall : onPause),
          ),
        ModelAction(
          icon: Icons.close_rounded,
          tooltip: state.pausable ? l10n.downloadCancel : l10n.downloadCancelNotResumable,
          onPressed: stopping ? null : onCancel,
        ),
      ];
    } else if (!state.installed) {
      actions = [
        ModelAction(
          icon: Icons.download_rounded,
          tooltip: l10n.modelDownload,
          onPressed: running ? null : onInstall,
        ),
      ];
    } else {
      actions = [
        ModelAction(
          icon: Icons.delete_outline_rounded,
          tooltip: running ? l10n.runtimeRemoveLocked : l10n.computeRuntimeRemove,
          onPressed: running
              ? null
              : () async {
                  final confirmed = await confirmModelRemoval(
                    context,
                    title: l10n.computeRuntimeRemoveTitle,
                    message: l10n.computeRuntimeRemoveMessage(size),
                    confirmLabel: l10n.computeRuntimeRemoveConfirm,
                  );
                  if (confirmed) onRemove();
                },
        ),
      ];
    }
    return ModelTile(
      title: title,
      parts: [
        ModelTilePart(
          label: runtimeServes(l10n, package.id),
          bytes: package.approximateBytes,
          installed: state.installed,
        ),
      ],
      progress: progress,
      paused: state.paused,
      installed: state.installed,
      inUse: inUse && state.installed && progress == null,
      marked: inUse && state.installed,
      tooltip: [
        title,
        if (progress != null)
          l10n.whisperDownloadProgress(
            (progress * 100).round(),
            formatPackageSize((package.approximateBytes * progress).round()),
            size,
          )
        else if (!state.installed)
          l10n.computeRuntimeMissing(size)
        else if (inUse)
          l10n.runtimeHintInUse
        else
          l10n.runtimeHintIdle,
      ].join('\n'),
      onTap: null,
      actions: actions,
    );
  }
}
