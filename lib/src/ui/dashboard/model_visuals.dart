// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/model_package.dart';
import '../failure_messages.dart';
import '../model_names.dart';
import '../theme.dart';

/// The pieces every model on the Models screen is drawn with — the Whisper
/// bars and the tiles alike — so a download, a pause or a delete looks and
/// behaves the same wherever it is.

/// Something a model offers: download, pause, resume, cancel or delete.
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
  final downloading = [
    for (final part in parts)
      if (part.downloading) part,
  ];
  final paused = [
    for (final part in parts)
      if (part.paused) part,
  ];
  final missing = [
    for (final part in parts)
      if (!part.installed && part.progress == null) part,
  ];
  final stopping = parts.any((part) => isStopping(part.model.id));
  if (downloading.isNotEmpty || paused.isNotEmpty) {
    final running = downloading.isNotEmpty;
    return [
      ModelAction(
        icon: running ? Icons.pause_rounded : Icons.play_arrow_rounded,
        tooltip: stopping
            ? l10n.downloadStopping
            : running
            ? l10n.downloadPause
            : l10n.downloadResume,
        onPressed: stopping
            ? null
            : () {
                if (running) {
                  downloading.forEach(onPause);
                } else {
                  // Resuming finishes the whole pair, not only the half
                  // that happened to be paused.
                  [...paused, ...missing].forEach(onInstall);
                }
              },
      ),
      ModelAction(
        icon: Icons.close_rounded,
        tooltip: l10n.downloadCancel,
        onPressed: stopping ? null : () => [...downloading, ...paused].forEach(onCancel),
      ),
    ];
  }
  return [
    if (missing.isNotEmpty)
      ModelAction(
        icon: Icons.download_rounded,
        tooltip: l10n.modelDownload,
        onPressed: () => missing.forEach(onInstall),
      ),
    if (parts.any((part) => part.installed))
      ModelAction(
        icon: Icons.delete_outline_rounded,
        tooltip: locked ? l10n.modelRemoveInUse : l10n.modelRemove,
        onPressed: locked ? null : onRemove,
      ),
  ];
}

/// A model's button: small enough for the narrowest Whisper bar, and light
/// once the dark fill of a download or of the model in use is behind it.
class ModelActionButton extends StatelessWidget {
  const ModelActionButton({super.key, required this.action, required this.onDark});

  final ModelAction action;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final colour = onDark ? LoreDubPalette.raised : LoreDubPalette.ink;
    return IconButton(
      tooltip: action.tooltip,
      onPressed: action.onPressed,
      icon: Icon(action.icon, size: 19),
      style: IconButton.styleFrom(
        foregroundColor: colour,
        disabledForegroundColor: colour.withValues(alpha: 0.35),
        hoverColor: LoreDubPalette.orange.withValues(alpha: 0.18),
        minimumSize: const Size(34, 34),
        fixedSize: const Size(34, 34),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// Grows its child a little under the pointer, so the model about to be
/// clicked stands out without the layout shifting around it.
class HoverGrow extends StatefulWidget {
  const HoverGrow({
    super.key,
    required this.builder,
    this.alignment = Alignment.bottomCenter,
    this.scale = 1.04,
  });

  final Widget Function(BuildContext context, bool hovered) builder;

  /// The point that stays put: a Whisper bar grows up from its axis.
  final Alignment alignment;
  final double scale;

  @override
  State<HoverGrow> createState() => _HoverGrowState();
}

class _HoverGrowState extends State<HoverGrow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? widget.scale : 1,
        alignment: widget.alignment,
        duration: still ? Duration.zero : const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: widget.builder(context, _hovered),
      ),
    );
  }
}

/// The share downloaded as a ring that fills clockwise from the top, with
/// the figure inside it. Orange reads on the light face of a model and on
/// its dark fill alike; a paused download dims its arc.
class ModelProgressDial extends StatelessWidget {
  const ModelProgressDial({
    super.key,
    required this.progress,
    required this.paused,
    required this.size,
  });

  final double progress;
  final bool paused;
  final double size;

  @override
  Widget build(BuildContext context) {
    final stroke = (size * 0.08).clamp(3.0, 7.0);
    return SizedBox.square(
      dimension: size,
      // Progress arrives in steps; the arc glides between them.
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        builder: (context, value, child) => CustomPaint(
          painter: _ProgressRingPainter(value: value, paused: paused, stroke: stroke),
          child: child,
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(stroke + size * 0.07),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  fontFamily: LoreDubFonts.mono,
                  fontSize: math.max(12, size * 0.27),
                  fontWeight: FontWeight.w600,
                  color: LoreDubPalette.orange,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A dashed track with the downloaded share laid over it as a solid arc.
class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({required this.value, required this.paused, required this.stroke});

  final double value;
  final bool paused;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final track = Paint()
      ..color = LoreDubPalette.orange.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, stroke * 0.45);
    const segments = 36;
    const sweep = 2 * math.pi / segments;
    for (var index = 0; index < segments; index++) {
      canvas.drawArc(rect, index * sweep, sweep * 0.55, false, track);
    }
    if (value <= 0) return;
    final arc = Paint()
      ..color = paused ? LoreDubPalette.orange.withValues(alpha: 0.55) : LoreDubPalette.orange
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value, false, arc);
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.paused != paused || oldDelegate.stroke != stroke;
}

/// Asks before a model leaves the disk: hundreds of megabytes are not worth
/// losing to a stray click.
Future<bool> confirmModelRemoval(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(title),
      content: Text(message, style: const TextStyle(fontSize: 16, height: 1.4)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.modelRemoveCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Colors.white,
          ),
          child: Text(l10n.modelRemoveConfirm),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// A download that failed. Its model went back to "not downloaded", so its
/// own button tries again; the reason needs more room than a card has.
class ModelFailureRow extends StatelessWidget {
  const ModelFailureRow({super.key, required this.state});

  final ModelInstallState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: ValueKey('modelFailure-${state.model.id}'),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: LoreDubPalette.panel,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(color: LoreDubPalette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(modelTitle(l10n, state.model), style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          SelectableText(
            describeFailure(l10n, state.error!),
            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
