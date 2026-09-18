// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/glossary.dart';
import '../theme.dart';
import 'glossary_drag.dart';
import '../common/drag_feedback_chip.dart';

/// An entry inside a pack: what it is filed under, a handle to drag it out
/// by, and the cross that takes it out without dragging.
class GlossaryPackedEntry extends StatelessWidget {
  const GlossaryPackedEntry({
    super.key,
    required this.entry,
    required this.packId,
    required this.maxWidth,
    required this.onRemove,
  });

  final GlossaryEntry entry;
  final String packId;

  /// What the row it sits in can spare. A quotation runs to a line and a
  /// half, and the chip is cut to fit rather than allowed to run off.
  final double maxWidth;
  final VoidCallback onRemove;

  /// The icon, the spacing and the cross the text stands beside.
  static const _furniture = 74.0;

  static IconData _iconOf(GlossaryKind kind) => switch (kind) {
    GlossaryKind.phrase => Icons.format_quote_rounded,
    GlossaryKind.name => Icons.badge_outlined,
    GlossaryKind.word => Icons.text_fields_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            Icon(_iconOf(entry.kind), size: 16, color: LoreDubPalette.mutedInk),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: (maxWidth - _furniture).clamp(40.0, 520.0)),
              child: Text(
                entry.source,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: l10n.packsRemoveMember,
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 15),
              style: IconButton.styleFrom(
                minimumSize: const Size(26, 26),
                fixedSize: const Size(26, 26),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
    return Draggable<GlossaryDrag>(
      data: GlossaryDrag(entry: entry, fromPackId: packId),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: DragFeedbackChip(label: entry.source),
      childWhenDragging: Opacity(opacity: 0.4, child: chip),
      // The whole of it where the chip shows only the head.
      child: Tooltip(message: entry.source, child: chip),
    );
  }
}
