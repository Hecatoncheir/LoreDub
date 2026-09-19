// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../theme.dart';

/// Something inside a pack: what it is, a handle to drag it out by -- the
/// chip itself, carrying [data] -- and the cross that takes it out without
/// dragging.
class PackChip<D extends Object> extends StatelessWidget {
  const PackChip({
    super.key,
    required this.data,
    required this.icon,
    required this.label,
    required this.feedback,
    required this.onRemove,
    this.iconColor = LoreDubPalette.mutedInk,
    this.maxWidth,
    this.tooltip,
  });

  final D data;
  final IconData icon;
  final Color iconColor;
  final String label;

  /// What travels under the pointer while the chip is dragged.
  final Widget feedback;
  final VoidCallback onRemove;

  /// What the row the chip sits in can spare, when the label may run longer
  /// than that; the label is then cut to fit rather than allowed to run off.
  final double? maxWidth;

  /// The whole of the label, where the chip shows only its head.
  final String? tooltip;

  /// The icon, the spacing and the cross the label stands beside.
  static const _furniture = 74.0;

  double get _labelWidth {
    final room = maxWidth;
    return room == null ? double.infinity : (room - _furniture).clamp(40.0, 520.0);
  }

  @override
  Widget build(BuildContext context) {
    final chip = Material(
      color: LoreDubPalette.raised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: LoreDubPalette.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _labelWidth),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: AppLocalizations.of(context).packsRemoveMember,
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 15),
              style: IconButton.styleFrom(
                minimumSize: const Size.square(LoreDubTargets.cross),
                fixedSize: const Size.square(LoreDubTargets.cross),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
    final whole = tooltip;
    return Draggable<D>(
      data: data,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: feedback,
      childWhenDragging: Opacity(opacity: 0.4, child: chip),
      child: whole == null ? chip : Tooltip(message: whole, child: chip),
    );
  }
}
