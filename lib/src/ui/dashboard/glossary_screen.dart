// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/glossary.dart';
import '../theme.dart';
import 'cubits/dashboard_cubits.dart';
import 'cubits/glossary_cubit.dart';

/// The screen where the player writes down what the dubbing cannot know.
///
/// Two lists rather than one, because the two entries reach a line at
/// different moments and behave differently: a phrase is answered before the
/// model is asked at all, while a name only replaces what the model left in
/// Latin script. Kept apart so that neither is expected to do the other's
/// work -- a name written here does not rewrite the Russian the model
/// already declined for itself.
class GlossaryPanel extends StatelessWidget {
  const GlossaryPanel({super.key, required this.cubits});

  final DashboardCubits cubits;

  static const _json = [
    XTypeGroup(label: 'LoreDub', extensions: ['json']),
  ];

  Future<void> _export() async {
    final location = await getSaveLocation(
      suggestedName: 'loredub-glossary.json',
      acceptedTypeGroups: _json,
    );
    if (location == null) return;
    await cubits.glossary.export(location.path);
  }

  Future<void> _import() async {
    final chosen = await openFiles(acceptedTypeGroups: _json);
    if (chosen.isEmpty) return;
    await cubits.glossary.import([for (final file in chosen) file.path]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<GlossaryCubit, GlossaryState>(
      bloc: cubits.glossary,
      builder: (context, state) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Over both lists rather than beside either: one file holds them
            // together, and a glossary of a game is worth passing on whole.
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    key: const ValueKey('glossary-import'),
                    onPressed: _import,
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: Text(l10n.glossaryImport),
                    style: TextButton.styleFrom(foregroundColor: LoreDubPalette.mutedInk),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    key: const ValueKey('glossary-export'),
                    onPressed: state.glossary.isEmpty ? null : _export,
                    icon: const Icon(Icons.file_upload_outlined, size: 18),
                    label: Text(l10n.glossaryExport),
                    style: TextButton.styleFrom(foregroundColor: LoreDubPalette.mutedInk),
                  ),
                ],
              ),
            ),
            _GlossarySection(
              number: '01',
              label: l10n.glossaryPhrases,
              note: l10n.glossaryPhrasesNote,
              sourceLabel: l10n.glossaryPhraseSource,
              readingLabel: l10n.glossaryPhraseReading,
              kind: GlossaryKind.phrase,
              entries: state.glossary.of(GlossaryKind.phrase).toList(),
              loaded: state.loaded,
              cubits: cubits,
            ),
            const SizedBox(height: 16),
            _GlossarySection(
              number: '02',
              label: l10n.glossaryNames,
              note: l10n.glossaryNamesNote,
              sourceLabel: l10n.glossaryNameSource,
              readingLabel: l10n.glossaryNameReading,
              kind: GlossaryKind.name,
              entries: state.glossary.of(GlossaryKind.name).toList(),
              loaded: state.loaded,
              cubits: cubits,
            ),
            const SizedBox(height: 16),
            _GlossarySection(
              number: '03',
              label: l10n.glossaryWords,
              note: l10n.glossaryWordsNote,
              sourceLabel: l10n.glossaryWordSource,
              readingLabel: l10n.glossaryWordReading,
              kind: GlossaryKind.word,
              entries: state.glossary.of(GlossaryKind.word).toList(),
              loaded: state.loaded,
              cubits: cubits,
            ),
          ],
        ),
      ),
    );
  }
}

class _GlossarySection extends StatelessWidget {
  const _GlossarySection({
    required this.number,
    required this.label,
    required this.note,
    required this.sourceLabel,
    required this.readingLabel,
    required this.kind,
    required this.entries,
    required this.loaded,
    required this.cubits,
  });

  final String number;
  final String label;
  final String note;
  final String sourceLabel;
  final String readingLabel;
  final GlossaryKind kind;
  final List<GlossaryEntry> entries;
  final bool loaded;
  final DashboardCubits cubits;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GlossaryLabel(number: number, label: label),
            const SizedBox(height: 10),
            Text(
              note,
              style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 13),
            ),
            const SizedBox(height: 14),
            if (loaded && entries.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l10n.glossaryEmpty,
                  style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 13),
                ),
              ),
            for (final entry in entries)
              _EntryRow(
                // By what it matches on: an entry being edited keeps its
                // field while the reading beside it is typed, and a source
                // renamed is a different entry.
                key: ValueKey('${kind.name}:${entry.key}'),
                entry: entry,
                sourceLabel: sourceLabel,
                readingLabel: readingLabel,
                onWrite: (written) => cubits.glossary.write(written),
                onRemove: () => cubits.glossary.remove(kind, entry.source),
              ),
            const SizedBox(height: 6),
            _AddRow(
              kind: kind,
              sourceLabel: sourceLabel,
              readingLabel: readingLabel,
              onWrite: (written) => cubits.glossary.write(written),
            ),
          ],
        ),
      ),
    );
  }
}

/// One entry, edited where it stands. Written back when the field is left or
/// submitted rather than on every keystroke: half a word is not an entry,
/// and the worker is told of each write.
class _EntryRow extends StatefulWidget {
  const _EntryRow({
    super.key,
    required this.entry,
    required this.sourceLabel,
    required this.readingLabel,
    required this.onWrite,
    required this.onRemove,
  });

  final GlossaryEntry entry;
  final String sourceLabel;
  final String readingLabel;
  final void Function(GlossaryEntry entry) onWrite;
  final VoidCallback onRemove;

  @override
  State<_EntryRow> createState() => _EntryRowState();
}

class _EntryRowState extends State<_EntryRow> {
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
        // The source is shown rather than edited: it is what the entry is
        // filed under, and editing it in place would silently found a second
        // entry while the first went on answering. Selectable all the same --
        // a phrase written down here came from somewhere and is wanted
        // elsewhere, and the reading beside it has always been copyable
        // simply by being a field.
        Expanded(
          child: SelectableText(widget.entry.source, style: const TextStyle(fontSize: 14)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward_rounded, size: 16, color: LoreDubPalette.mutedInk),
        ),
        Expanded(
          child: Focus(
            onFocusChange: (has) {
              if (!has) _commit();
            },
            child: TextField(
              controller: _reading,
              decoration: InputDecoration(labelText: widget.readingLabel, isDense: true),
              onSubmitted: (_) => _commit(),
            ),
          ),
        ),
        IconButton(
          tooltip: AppLocalizations.of(context).glossaryRemove,
          icon: const Icon(Icons.delete_outline_rounded, size: 20),
          onPressed: widget.onRemove,
        ),
      ],
    ),
  );
}

/// The empty line at the foot of a list, which becomes an entry once both
/// halves are written.
class _AddRow extends StatefulWidget {
  const _AddRow({
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
  State<_AddRow> createState() => _AddRowState();
}

class _AddRowState extends State<_AddRow> {
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
      Expanded(
        child: TextField(
          key: ValueKey('glossary-source-${widget.kind.name}'),
          controller: _source,
          decoration: InputDecoration(labelText: widget.sourceLabel, isDense: true),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _add(),
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Icon(Icons.arrow_forward_rounded, size: 16, color: LoreDubPalette.mutedInk),
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

/// The heading of a list, in the vocabulary the other screens use.
class _GlossaryLabel extends StatelessWidget {
  const _GlossaryLabel({required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 28,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: LoreDubPalette.orange,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: LoreDubPalette.ink),
        ),
        child: Text(
          number,
          style: const TextStyle(
            fontFamily: LoreDubFonts.mono,
            color: LoreDubPalette.ink,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Text(label, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}
