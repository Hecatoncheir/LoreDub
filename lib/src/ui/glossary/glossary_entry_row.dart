// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/glossary.dart';
import '../theme.dart';
import 'glossary_entry_handle.dart';

/// One entry, edited where it stands. Written back when the field is left or
/// submitted rather than on every keystroke: half a word is not an entry,
/// and the worker is told of each write.
class GlossaryEntryRow extends StatefulWidget {
  const GlossaryEntryRow({
    super.key,
    required this.entry,
    required this.sourceLabel,
    required this.readingLabel,
    required this.onWrite,
    required this.onRemove,
    this.packs = const [],
    this.onFileInPack,
  });

  final GlossaryEntry entry;
  final String sourceLabel;
  final String readingLabel;
  final void Function(GlossaryEntry entry) onWrite;
  final VoidCallback onRemove;

  /// Every pack on the shelf, offered from the handle to a hand that
  /// cannot drag -- a keyboard, a switch.
  final List<GlossaryPack> packs;
  final ValueChanged<String>? onFileInPack;

  @override
  State<GlossaryEntryRow> createState() => _GlossaryEntryRowState();
}

class _GlossaryEntryRowState extends State<GlossaryEntryRow> {
  late final _reading = TextEditingController(text: widget.entry.reading);

  @override
  void dispose() {
    _reading.dispose();
    super.dispose();
  }

  void _commit() {
    final written = _reading.text.trim();
    if (written.isEmpty || written == widget.entry.reading) return;
    widget.onWrite(widget.entry.copyWith(reading: written));
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        GlossaryEntryHandle(
          entry: widget.entry,
          packs: widget.packs,
          onFileInPack: widget.onFileInPack,
        ),
        // The source is shown rather than edited: it is what the entry is
        // filed under, and editing it in place would silently found a second
        // entry while the first went on answering. Selectable all the same --
        // a phrase written down here came from somewhere and is wanted
        // elsewhere, and the reading beside it has always been copyable
        // simply by being a field.
        Expanded(
          child: SelectableText(widget.entry.source, style: const TextStyle(fontSize: 14)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward_rounded, size: 16, color: context.colors.mutedInk),
        ),
        Expanded(
          child: Focus(
            onFocusChange: (has) {
              if (!has) _commit();
            },
            child: TextField(
              controller: _reading,
              // A silenced line has no reading to write: the field is left
              // standing so the row keeps its shape, and says what it is.
              enabled: !widget.entry.silent,
              decoration: InputDecoration(
                labelText: widget.readingLabel,
                hintText: widget.entry.silent
                    ? AppLocalizations.of(context).glossarySilenced
                    : null,
                isDense: true,
              ),
              onSubmitted: (_) => _commit(),
            ),
          ),
        ),
        // Only a phrase can be passed over: a name and a word stand inside a
        // line rather than being one.
        if (widget.entry.silences)
          IconButton(
            key: ValueKey('glossary-silence-${widget.entry.packKey}'),
            tooltip: widget.entry.silent
                ? AppLocalizations.of(context).glossarySpeakAgain
                : AppLocalizations.of(context).glossarySilence,
            icon: Icon(
              widget.entry.silent ? Icons.volume_off_rounded : Icons.volume_up_outlined,
              size: 20,
              color: widget.entry.silent ? context.colors.accent : context.colors.mutedInk,
            ),
            onPressed: () => widget.onWrite(widget.entry.copyWith(silent: !widget.entry.silent)),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            tooltip: AppLocalizations.of(context).glossaryRemove,
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            onPressed: widget.onRemove,
          ),
        ),
      ],
    ),
  );
}
