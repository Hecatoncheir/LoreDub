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

/// An entry on its way to a pack, and the pack it was dragged out of.
///
/// The source pack matters because dropping an entry on another pack moves
/// it rather than copying it: an entry may be in several packs, but dragging
/// one across says where it should be instead.
class GlossaryDrag {
  const GlossaryDrag({required this.entry, this.fromPackId});

  final GlossaryEntry entry;
  final String? fromPackId;
}

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

  /// A pack read back is merged the way the whole glossary is -- the entries
  /// it carries join the lists, and the grouping joins the shelf.
  Future<void> _importPack() => _import();

  Future<void> _exportPack(GlossaryPack pack) async {
    final location = await getSaveLocation(
      suggestedName: 'loredub-${pack.name.trim().isEmpty ? 'pack' : pack.name.trim()}.json',
      acceptedTypeGroups: _json,
    );
    if (location == null) return;
    await cubits.glossary.exportPack(location.path, pack.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<GlossaryCubit, GlossaryState>(
      bloc: cubits.glossary,
      builder: (context, state) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
        child: ListView(
          key: const ValueKey('glossaryList'),
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
            // The packs stand beside the lists where there is room for
            // both: a pack is chosen while looking at what goes into it, and
            // under three long lists it would be a scroll away from them. A
            // narrow window puts it back underneath, where a column of its
            // own would leave neither side readable.
            LayoutBuilder(
              builder: (context, constraints) {
                final lists = <Widget>[
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
                ];
                final packs = _GlossaryPacksSection(
                  glossary: state.glossary,
                  cubits: cubits,
                  onImport: _importPack,
                  onExport: _exportPack,
                );
                if (constraints.maxWidth < _packsBesideListsWidth) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [...lists, const SizedBox(height: 16), packs],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: lists,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(width: _glossaryPacksWidth, child: packs),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// What the handle an entry is dragged by takes on the left of a row. The
/// empty row at the foot of a list leaves the same width blank, so the
/// arrows down a list stand in one line.
const _dragHandleWidth = 24.0;

/// Beyond this the packs stand beside the lists rather than under them.
/// Below it the entry rows -- a source, an arrow and a field -- would be left
/// too narrow to read the pair in.
const _packsBesideListsWidth = 1040.0;

/// The column the packs get. The same width the scene voices take beside the
/// transcript, for the same reason: it is a list of short names.
const _glossaryPacksWidth = 340.0;

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
        Draggable<GlossaryDrag>(
          data: GlossaryDrag(entry: widget.entry),
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: _DragChip(label: widget.entry.source),
          child: Tooltip(
            message: AppLocalizations.of(context).glossaryPackDragHint,
            child: const SizedBox(
              width: _dragHandleWidth,
              child: Icon(
                Icons.drag_indicator_rounded,
                size: 18,
                color: LoreDubPalette.mutedInk,
              ),
            ),
          ),
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
      // The width of the drag handle the rows above carry, so that every
      // arrow in a list stands in the same place.
      const SizedBox(width: _dragHandleWidth),
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

/// What travels under the pointer while an entry is dragged.
class _DragChip extends StatelessWidget {
  const _DragChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Material(
    color: LoreDubPalette.graphite,
    borderRadius: const BorderRadius.all(Radius.circular(18)),
    elevation: 6,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Text(
        label,
        style: const TextStyle(color: LoreDubPalette.raised, fontSize: 13),
      ),
    ),
  );
}

/// The shelf of packs, under the three lists it groups.
///
/// A pack is a way of reading the glossary rather than a place entries are
/// moved to: every entry stays in its list whether or not a pack names it.
/// Switching one on narrows what the dubbing reads to the packs that are on
/// -- see [Glossary.inUse].
class _GlossaryPacksSection extends StatelessWidget {
  const _GlossaryPacksSection({
    required this.glossary,
    required this.cubits,
    required this.onImport,
    required this.onExport,
  });

  final Glossary glossary;
  final DashboardCubits cubits;
  final VoidCallback onImport;
  final ValueChanged<GlossaryPack> onExport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: const ValueKey('glossaryPacks'),
      decoration: BoxDecoration(
        color: LoreDubPalette.panel,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: LoreDubPalette.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GlossaryLabel(number: '04', label: l10n.glossaryPacks),
            const SizedBox(height: 4),
            // Wrapped rather than in a row: beside the lists this card is a
            // column narrower than the two buttons standing side by side.
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: [
                TextButton.icon(
                  key: const ValueKey('glossary-pack-import'),
                  onPressed: onImport,
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  label: Text(l10n.glossaryPackImport),
                  style: TextButton.styleFrom(foregroundColor: LoreDubPalette.mutedInk),
                ),
                TextButton.icon(
                  key: const ValueKey('glossary-pack-add'),
                  onPressed: () => cubits.glossary.addPack(l10n.packsNewName),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l10n.packsAdd),
                  style: TextButton.styleFrom(foregroundColor: LoreDubPalette.mutedInk),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.glossaryPacksNote,
              style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 13),
            ),
            const SizedBox(height: 14),
            if (glossary.packs.isEmpty)
              Text(
                l10n.glossaryPacksEmpty,
                style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 13),
              )
            else
              for (final pack in glossary.packs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _GlossaryPackArea(
                    key: ValueKey('glossary-pack-${pack.id}'),
                    pack: pack,
                    members: [
                      for (final entry in glossary.entries)
                        if (pack.holds(entry.packKey)) entry,
                    ],
                    onRename: (name) => cubits.glossary.renamePack(pack.id, name),
                    onActive: (active) => cubits.glossary.activatePack(pack.id, active: active),
                    onExport: pack.entryKeys.isEmpty ? null : () => onExport(pack),
                    onDelete: () => cubits.glossary.removePack(pack.id),
                    onDrop: (drag) => cubits.glossary.fileInPack(
                      drag.entry,
                      into: pack.id,
                      from: drag.fromPackId,
                    ),
                    onRemoveMember: (entry) => cubits.glossary.takeFromPack(entry, from: pack.id),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// One pack: its name, how many entries it holds, whether the dubbing reads
/// it, and those entries as chips that can be dragged out again.
class _GlossaryPackArea extends StatefulWidget {
  const _GlossaryPackArea({
    super.key,
    required this.pack,
    required this.members,
    required this.onRename,
    required this.onActive,
    required this.onExport,
    required this.onDelete,
    required this.onDrop,
    required this.onRemoveMember,
  });

  final GlossaryPack pack;
  final List<GlossaryEntry> members;
  final ValueChanged<String> onRename;
  final ValueChanged<bool> onActive;

  /// Null while the pack holds nothing worth writing to a file.
  final VoidCallback? onExport;
  final VoidCallback onDelete;
  final ValueChanged<GlossaryDrag> onDrop;
  final ValueChanged<GlossaryEntry> onRemoveMember;

  @override
  State<_GlossaryPackArea> createState() => _GlossaryPackAreaState();
}

class _GlossaryPackAreaState extends State<_GlossaryPackArea> {
  late final TextEditingController _name = TextEditingController(text: widget.pack.name);

  @override
  void didUpdateWidget(_GlossaryPackArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pack.name != oldWidget.pack.name && !_name.selection.isValid) {
      _name.text = widget.pack.name;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _rename() {
    final name = _name.text.trim();
    if (name.isEmpty || name == widget.pack.name) return;
    widget.onRename(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DragTarget<GlossaryDrag>(
      // An entry already in this pack is not offered a place in it again.
      onWillAcceptWithDetails: (details) => !widget.pack.holds(details.data.entry.packKey),
      onAcceptWithDetails: (details) => widget.onDrop(details.data),
      builder: (context, candidate, _) {
        final inviting = candidate.isNotEmpty;
        // An active pack wears the same orange edge a chosen thing wears
        // elsewhere: what is switched on is what the dubbing is reading.
        final marked = inviting || widget.pack.active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
          decoration: BoxDecoration(
            color: inviting ? LoreDubPalette.raised : LoreDubPalette.panel,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(
              color: marked ? LoreDubPalette.orange : LoreDubPalette.outline,
              width: marked ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The name on one line and what is done to the pack on the
              // next: in the column beside the lists a single row would
              // leave the name field a few pixels wide.
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _name,
                      style: const TextStyle(
                        fontFamily: LoreDubFonts.display,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.packsNameLabel,
                        isDense: true,
                      ),
                      onEditingComplete: _rename,
                      onTapOutside: (_) => _rename(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.glossaryPackCount(widget.members.length),
                    style: const TextStyle(
                      fontFamily: LoreDubFonts.mono,
                      fontSize: 11,
                      color: LoreDubPalette.mutedInk,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Tooltip(
                    message: l10n.glossaryPackActiveHint,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          key: ValueKey('glossary-pack-active-${widget.pack.id}'),
                          value: widget.pack.active,
                          onChanged: widget.onActive,
                        ),
                        Text(
                          l10n.glossaryPackActive,
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.pack.active
                                ? LoreDubPalette.orange
                                : LoreDubPalette.mutedInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: l10n.packsExportHint,
                    onPressed: widget.onExport,
                    icon: const Icon(Icons.file_upload_outlined, size: 20),
                  ),
                  IconButton(
                    tooltip: l10n.packsDelete,
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (widget.members.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
                  child: Text(
                    l10n.glossaryPackDropHint,
                    style: const TextStyle(fontSize: 12, color: LoreDubPalette.mutedInk),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final member in widget.members)
                      _PackedEntry(
                        entry: member,
                        packId: widget.pack.id,
                        onRemove: () => widget.onRemoveMember(member),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// An entry inside a pack: what it is filed under, a handle to drag it out
/// by, and the cross that takes it out without dragging.
class _PackedEntry extends StatelessWidget {
  const _PackedEntry({required this.entry, required this.packId, required this.onRemove});

  final GlossaryEntry entry;
  final String packId;
  final VoidCallback onRemove;

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
            Text(
              entry.source,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
      feedback: _DragChip(label: entry.source),
      childWhenDragging: Opacity(opacity: 0.4, child: chip),
      child: chip,
    );
  }
}
