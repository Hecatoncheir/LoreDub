// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../domain/glossary.dart';
import '../common/drag_feedback_chip.dart';
import '../common/pack_chip.dart';
import 'glossary_drag.dart';

/// An entry inside a pack: what it is filed under, cut to the row it sits
/// in, and the chip to drag it out by.
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

  static IconData _iconOf(GlossaryKind kind) => switch (kind) {
    GlossaryKind.phrase => Icons.format_quote_rounded,
    GlossaryKind.name => Icons.badge_outlined,
    GlossaryKind.word => Icons.text_fields_rounded,
  };

  @override
  Widget build(BuildContext context) => PackChip<GlossaryDrag>(
    data: GlossaryDrag(entry: entry, fromPackId: packId),
    icon: _iconOf(entry.kind),
    label: entry.source,
    maxWidth: maxWidth,
    tooltip: entry.source,
    feedback: DragFeedbackChip(label: entry.source),
    onRemove: onRemove,
  );
}
