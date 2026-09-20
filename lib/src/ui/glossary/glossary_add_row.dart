// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/glossary.dart';
import '../theme.dart';
import 'glossary_layout.dart';

/// The empty line at the foot of a list, which becomes an entry once both
/// halves are written.
class GlossaryAddRow extends StatefulWidget {
  const GlossaryAddRow({
    super.key,
    required this.kind,
    required this.sourceLabel,
    required this.readingLabel,
    required this.onWrite,
  });

  final GlossaryKind kind;
  final String sourceLabel;
  final String readingLabel;
  final void Function(GlossaryEntry entry) onWrite;

  @override
  State<GlossaryAddRow> createState() => _GlossaryAddRowState();
}

class _GlossaryAddRowState extends State<GlossaryAddRow> {
  final _source = TextEditingController();
  final _reading = TextEditingController();

  @override
  void dispose() {
    _source.dispose();
    _reading.dispose();
    super.dispose();
  }

  void _add() {
    final source = _source.text.trim();
    final reading = _reading.text.trim();
    if (source.isEmpty || reading.isEmpty) return;
    widget.onWrite(GlossaryEntry(kind: widget.kind, source: source, reading: reading));
    _source.clear();
    _reading.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      // The width of the drag handle the rows above carry, so that every
      // arrow in a list stands in the same place.
      const SizedBox(width: GlossaryLayout.dragHandleWidth),
      Expanded(
        child: TextField(
          key: ValueKey('glossary-source-${widget.kind.name}'),
          controller: _source,
          decoration: InputDecoration(labelText: widget.sourceLabel, isDense: true),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _add(),
        ),
      ),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Icon(Icons.arrow_forward_rounded, size: 16, color: context.colors.mutedInk),
      ),
      Expanded(
        child: TextField(
          key: ValueKey('glossary-reading-${widget.kind.name}'),
          controller: _reading,
          decoration: InputDecoration(labelText: widget.readingLabel, isDense: true),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _add(),
        ),
      ),
      // The width the rows above give to the button that passes a line over,
      // so that the arrows down the list stand in one line.
      if (widget.kind == GlossaryKind.phrase)
        const SizedBox(width: GlossaryLayout.silenceSlotWidth),
      Padding(
        padding: const EdgeInsets.only(left: 4),
        child: IconButton.filled(
          key: ValueKey('glossary-add-${widget.kind.name}'),
          tooltip: AppLocalizations.of(context).glossaryAdd,
          icon: const Icon(Icons.add_rounded, size: 20),
          onPressed: _source.text.trim().isEmpty || _reading.text.trim().isEmpty ? null : _add,
        ),
      ),
    ],
  );
}
