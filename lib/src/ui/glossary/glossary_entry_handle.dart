// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/glossary.dart';
import '../common/drag_feedback_chip.dart';
import '../theme.dart';
import 'glossary_drag.dart';
import 'glossary_layout.dart';

/// The handle an entry is carried into a pack by -- dragged, or clicked for
/// the list of packs, which is the way in for a keyboard. A drag is only
/// taken once the pointer has moved, so a click still reaches the menu.
class GlossaryEntryHandle extends StatelessWidget {
  const GlossaryEntryHandle({
    super.key,
    required this.entry,
    required this.packs,
    required this.onFileInPack,
  });

  final GlossaryEntry entry;

  /// Every pack on the shelf; the ones already holding the entry are shown
  /// and left out.
  final List<GlossaryPack> packs;
  final ValueChanged<String>? onFileInPack;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    key: ValueKey('glossary-handle-${entry.packKey}'),
    tooltip: AppLocalizations.of(context).glossaryPackDragHint,
    enabled: packs.isNotEmpty && onFileInPack != null,
    onSelected: onFileInPack,
    itemBuilder: (context) => [
      for (final pack in packs)
        PopupMenuItem(
          value: pack.id,
          enabled: !pack.holds(entry.packKey),
          child: Text(AppLocalizations.of(context).packsFileInto(pack.name)),
        ),
    ],
    child: Draggable<GlossaryDrag>(
      data: GlossaryDrag(entry: entry),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: DragFeedbackChip(label: entry.source),
      child: const SizedBox(
        width: GlossaryLayout.dragHandleWidth,
        child: Icon(Icons.drag_indicator_rounded, size: 18, color: LoreDubPalette.mutedInk),
      ),
    ),
  );
}
