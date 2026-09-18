// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/glossary.dart';
import '../theme.dart';
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
class GlossaryPanel extends StatefulWidget {
  const GlossaryPanel({super.key});

  @override
  State<GlossaryPanel> createState() => _GlossaryPanelState();
}

class _GlossaryPanelState extends State<GlossaryPanel> {
  static const _json = [
    XTypeGroup(label: 'LoreDub', extensions: ['json']),
  ];

  final _search = TextEditingController();

  /// What the lists are narrowed to. A glossary grows to hundreds of lines,
  /// and the one being looked for is usually remembered by a word of it
  /// rather than by where it stands.
  String _looking = '';

  /// Show only what no pack holds. On to begin with: the packs that come
  /// with the application put a hundred entries into these lists, and the
  /// handful the player wrote themselves would be lost among them. Turning
  /// it off shows the glossary whole.
  bool _looseOnly = true;

  /// Show only the lines that are passed over rather than said.
  bool _silentOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Either half answers: the player may remember the English they heard or
  /// the Russian they wrote.
  bool _matches(GlossaryEntry entry) {
    if (_looking.isEmpty) return true;
    return entry.source.toLowerCase().contains(_looking) ||
        entry.reading.toLowerCase().contains(_looking);
  }

  /// The presets narrow the lists and not the packs: a pack showing none of
  /// its own members would read as empty, which it is not.
  bool _listed(Glossary glossary, GlossaryEntry entry) {
    if (!_matches(entry)) return false;
    if (_silentOnly && !entry.silent) return false;
    if (_looseOnly && glossary.packsHolding(entry).isNotEmpty) return false;
    return true;
  }

  List<GlossaryEntry> _of(Glossary glossary, GlossaryKind kind) => [
    for (final entry in glossary.of(kind))
      if (_listed(glossary, entry)) entry,
  ];

  Widget _preset({
    required String label,
    required bool chosen,
    required ValueChanged<bool> onChanged,
    required String id,
  }) => FilterChip(
    key: ValueKey('glossary-preset-$id'),
    label: Text(label),
    selected: chosen,
    onSelected: onChanged,
    showCheckmark: true,
    visualDensity: VisualDensity.compact,
  );

  Future<void> _export() async {
    final glossary = context.read<GlossaryCubit>();
    final location = await getSaveLocation(
      suggestedName: 'loredub-glossary.json',
      acceptedTypeGroups: _json,
    );
    if (location == null) return;
    await glossary.export(location.path);
  }

  Future<void> _import() async {
    final glossary = context.read<GlossaryCubit>();
    final chosen = await openFiles(acceptedTypeGroups: _json);
    if (chosen.isEmpty) return;
    await glossary.import([for (final file in chosen) file.path]);
  }

  /// A pack read back is merged the way the whole glossary is -- the entries
  /// it carries join the lists, and the grouping joins the shelf.
  Future<void> _importPack() => _import();

  Future<void> _exportPack(GlossaryPack pack) async {
    final glossary = context.read<GlossaryCubit>();
    final location = await getSaveLocation(
      suggestedName: 'loredub-${pack.name.trim().isEmpty ? 'pack' : pack.name.trim()}.json',
      acceptedTypeGroups: _json,
    );
    if (location == null) return;
    await glossary.exportPack(location.path, pack.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<GlossaryCubit, GlossaryState>(
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
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('glossary-search'),
                      controller: _search,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: l10n.glossarySearch,
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        suffixIcon: _looking.isEmpty
                            ? null
                            : IconButton(
                                key: const ValueKey('glossary-search-clear'),
                                tooltip: l10n.glossarySearchClear,
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _looking = '');
                                },
                              ),
                      ),
                      onChanged: (value) => setState(() => _looking = value.trim().toLowerCase()),
                    ),
                  ),
                  const SizedBox(width: 12),
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
            // Two ready answers to questions the player asks often enough to
            // deserve a press rather than a typed word.
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _preset(
                    id: 'loose',
                    label: l10n.glossaryOnlyLoose,
                    chosen: _looseOnly,
                    onChanged: (value) => setState(() => _looseOnly = value),
                  ),
                  _preset(
                    id: 'silent',
                    label: l10n.glossaryOnlySilent,
                    chosen: _silentOnly,
                    onChanged: (value) => setState(() => _silentOnly = value),
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
                    entries: _of(state.glossary, GlossaryKind.phrase),
                    held: state.glossary.of(GlossaryKind.phrase).length,
                    loaded: state.loaded,
                  ),
                  const SizedBox(height: 16),
                  _GlossarySection(
                    number: '02',
                    label: l10n.glossaryNames,
                    note: l10n.glossaryNamesNote,
                    sourceLabel: l10n.glossaryNameSource,
                    readingLabel: l10n.glossaryNameReading,
                    kind: GlossaryKind.name,
                    entries: _of(state.glossary, GlossaryKind.name),
                    held: state.glossary.of(GlossaryKind.name).length,
                    loaded: state.loaded,
                  ),
                  const SizedBox(height: 16),
                  _GlossarySection(
                    number: '03',
                    label: l10n.glossaryWords,
                    note: l10n.glossaryWordsNote,
                    sourceLabel: l10n.glossaryWordSource,
                    readingLabel: l10n.glossaryWordReading,
                    kind: GlossaryKind.word,
                    entries: _of(state.glossary, GlossaryKind.word),
                    held: state.glossary.of(GlossaryKind.word).length,
                    loaded: state.loaded,
                  ),
                ];
                final packs = _GlossaryPacksSection(
                  glossary: state.glossary,
                  matches: _matches,
                  searching: _looking.isNotEmpty,
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

/// And what the button that passes a line over takes on the right of one.
/// Only a phrase carries it, so only the phrase list leaves room for it.
const _silenceSlotWidth = 48.0;

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
    required this.held,
    required this.loaded,
  });

  final String number;
  final String label;
  final String note;
  final String sourceLabel;
  final String readingLabel;
  final GlossaryKind kind;

  /// What the list shows: its entries, narrowed by the search and the
  /// presets.
  final List<GlossaryEntry> entries;

  /// How many are written down, whatever is shown of them, which is what
  /// tells a list with nothing in it from one narrowed to nothing.
  final int held;
  final bool loaded;

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
                  // A list with nothing in it says so; one whose entries the
                  // search or a preset hid says that instead, as a pack does.
                  // "In no pack" is on to begin with, so names filed in a
                  // game's pack would open on "nothing here yet" -- and one
                  // written under a narrowed list, hidden the moment it is
                  // kept, would read as not having been written.
                  held > 0 ? l10n.glossaryAllHidden : l10n.glossaryEmpty,
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
                onWrite: (written) => context.read<GlossaryCubit>().write(written),
                onRemove: () => context.read<GlossaryCubit>().remove(kind, entry.source),
              ),
            const SizedBox(height: 6),
            _AddRow(
              kind: kind,
              sourceLabel: sourceLabel,
              readingLabel: readingLabel,
              onWrite: (written) => context.read<GlossaryCubit>().write(written),
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
              color: widget.entry.silent ? LoreDubPalette.orange : LoreDubPalette.mutedInk,
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
      // The width the rows above give to the button that passes a line over,
      // so that the arrows down the list stand in one line.
      if (widget.kind == GlossaryKind.phrase) const SizedBox(width: _silenceSlotWidth),
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: LoreDubPalette.raised, fontSize: 13),
        ),
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
    required this.matches,
    required this.searching,
    required this.onImport,
    required this.onExport,
  });

  final Glossary glossary;

  /// The same filter the three lists are under: a search narrows what a pack
  /// shows as well, so a line can be found and dragged in one motion.
  final bool Function(GlossaryEntry entry) matches;

  /// Whether a search is on, which is what tells an empty pack from one whose
  /// entries are all filtered away.
  final bool searching;
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
                  onPressed: () => context.read<GlossaryCubit>().addPack(l10n.packsNewName),
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
                        if (pack.holds(entry.packKey) && matches(entry)) entry,
                    ],
                    // The count is the pack's own, not what the search left:
                    // the pack did not change, only what is shown of it.
                    held: pack.entryKeys.length,
                    searching: searching,
                    onRename: (name) => context.read<GlossaryCubit>().renamePack(pack.id, name),
                    onActive: (active) =>
                        context.read<GlossaryCubit>().activatePack(pack.id, active: active),
                    onExport: pack.entryKeys.isEmpty ? null : () => onExport(pack),
                    onDelete: () => context.read<GlossaryCubit>().removePack(pack.id),
                    onDrop: (drag) => context.read<GlossaryCubit>().fileInPack(
                      drag.entry,
                      into: pack.id,
                      from: drag.fromPackId,
                    ),
                    onRemoveMember: (entry) =>
                        context.read<GlossaryCubit>().takeFromPack(entry, from: pack.id),
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
    required this.held,
    required this.searching,
    required this.onRename,
    required this.onActive,
    required this.onExport,
    required this.onDelete,
    required this.onDrop,
    required this.onRemoveMember,
  });

  final GlossaryPack pack;

  /// What the pack shows: its entries, narrowed by the search when there is
  /// one.
  final List<GlossaryEntry> members;

  /// How many it actually holds, which the count says whatever is shown.
  final int held;
  final bool searching;
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
                    l10n.glossaryPackCount(widget.held),
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
                    // A pack with nothing in it asks to be filled; one whose
                    // entries the search hid says so instead, or the player
                    // would read it as empty.
                    widget.searching && widget.held > 0
                        ? l10n.glossaryPackNothingFound
                        : l10n.glossaryPackDropHint,
                    style: const TextStyle(fontSize: 12, color: LoreDubPalette.mutedInk),
                  ),
                )
              else
                // A Wrap gives its children all the room they ask for, and a
                // phrase asks for the whole of itself: without a cap the
                // chips run off the side of the card.
                LayoutBuilder(
                  builder: (context, room) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final member in widget.members)
                        _PackedEntry(
                          entry: member,
                          packId: widget.pack.id,
                          maxWidth: room.maxWidth,
                          onRemove: () => widget.onRemoveMember(member),
                        ),
                    ],
                  ),
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
  const _PackedEntry({
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
      feedback: _DragChip(label: entry.source),
      childWhenDragging: Opacity(opacity: 0.4, child: chip),
      // The whole of it where the chip shows only the head.
      child: Tooltip(message: entry.source, child: chip),
    );
  }
}
