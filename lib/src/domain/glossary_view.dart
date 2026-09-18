// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'glossary.dart';

/// What the glossary screen is narrowed to.
class GlossaryFilter {
  const GlossaryFilter({this.looking = '', this.looseOnly = true, this.silentOnly = false});

  /// A word of the entry being looked for, lower-cased. A glossary grows to
  /// hundreds of lines, and the one being looked for is usually remembered
  /// by a word of it rather than by where it stands.
  final String looking;

  /// Only what no pack holds. On to begin with: the packs that come with the
  /// application put a hundred entries into the lists, and the handful the
  /// player wrote themselves would be lost among them.
  final bool looseOnly;

  /// Only the lines that are passed over rather than said.
  final bool silentOnly;

  bool get searching => looking.isNotEmpty;

  GlossaryFilter copyWith({String? looking, bool? looseOnly, bool? silentOnly}) => GlossaryFilter(
    looking: looking ?? this.looking,
    looseOnly: looseOnly ?? this.looseOnly,
    silentOnly: silentOnly ?? this.silentOnly,
  );

  /// Whether the search finds [entry]. Either half answers: the player may
  /// remember the English they heard or the reading they wrote.
  bool matches(GlossaryEntry entry) =>
      !searching ||
      entry.source.toLowerCase().contains(looking) ||
      entry.reading.toLowerCase().contains(looking);
}

/// The glossary as the screen shows it under a [GlossaryFilter].
///
/// The presets narrow the lists and not the packs: a pack showing none of
/// its own members would read as empty, which it is not. The search narrows
/// both, so a line can be found and dragged into a pack in one motion.
class GlossaryView {
  GlossaryView(this.glossary, this.filter)
    : _packed = {
        for (final pack in glossary.packs) ...pack.entryKeys,
      };

  final Glossary glossary;
  final GlossaryFilter filter;

  /// Every entry some pack holds, gathered once rather than asked of every
  /// pack for every entry on every keystroke.
  final Set<String> _packed;

  bool _listed(GlossaryEntry entry) =>
      filter.matches(entry) &&
      (!filter.silentOnly || entry.silent) &&
      (!filter.looseOnly || !_packed.contains(entry.packKey));

  /// The entries of [kind] the list shows.
  List<GlossaryEntry> listed(GlossaryKind kind) => [
    for (final entry in glossary.of(kind))
      if (_listed(entry)) entry,
  ];

  /// How many entries of [kind] are written down, whatever is shown of them:
  /// what tells a list with nothing in it from one narrowed to nothing.
  int held(GlossaryKind kind) => glossary.of(kind).length;

  /// The entries [pack] shows: its own, narrowed by the search alone.
  List<GlossaryEntry> membersOf(GlossaryPack pack) {
    final keys = pack.entryKeys.toSet();
    return [
      for (final entry in glossary.entries)
        if (keys.contains(entry.packKey) && filter.matches(entry)) entry,
    ];
  }
}
