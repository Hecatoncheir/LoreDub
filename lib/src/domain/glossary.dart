// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// What the player has told the dubbing about the games they play.
///
/// Two kinds, because they reach the line at two different moments and
/// neither can do the other's work.
enum GlossaryKind {
  /// A word the translator left in Latin script, written the way the player
  /// wants it said. It replaces the transliteration the worker would write
  /// otherwise, and it is applied nowhere else: measured, the model
  /// transliterates and correctly declines the names it does render --
  /// "The people of Megaton" comes back as "Жители Мегатона" -- so a
  /// nominative put over the whole line would break the grammar it found.
  name,

  /// A whole sentence with the translation the player wants for it. The
  /// model is not wrong about "Fire in the hole!" so much as ignorant of the
  /// game, and no better model fixes that.
  phrase,
}

/// One thing the player has said about their games.
class GlossaryEntry {
  const GlossaryEntry({required this.kind, required this.source, required this.reading});

  /// What is matched, as the player wrote it: a Latin word for a [name], an
  /// English sentence for a [phrase].
  final String source;

  /// What is said instead.
  final String reading;

  final GlossaryKind kind;

  /// What the match is made on. Whitespace and case say nothing here: whisper
  /// capitalizes a line by where it falls in a sentence, and a shout comes
  /// back in capitals.
  String get key => normalizedGlossaryKey(source);

  bool get isEmpty => source.trim().isEmpty || reading.trim().isEmpty;

  GlossaryEntry copyWith({GlossaryKind? kind, String? source, String? reading}) => GlossaryEntry(
    kind: kind ?? this.kind,
    source: source ?? this.source,
    reading: reading ?? this.reading,
  );

  Map<String, Object?> toJson() => {'kind': kind.name, 'source': source, 'reading': reading};

  static GlossaryEntry? fromJson(Object? value) {
    if (value is! Map) return null;
    final source = value['source'];
    final reading = value['reading'];
    if (source is! String || reading is! String) return null;
    final entry = GlossaryEntry(
      kind: value['kind'] == GlossaryKind.phrase.name ? GlossaryKind.phrase : GlossaryKind.name,
      source: source,
      reading: reading,
    );
    return entry.isEmpty ? null : entry;
  }

  @override
  bool operator ==(Object other) =>
      other is GlossaryEntry &&
      other.kind == kind &&
      other.source == source &&
      other.reading == reading;

  @override
  int get hashCode => Object.hash(kind, source, reading);
}

/// The match key of [source]: what is compared rather than what is shown.
String normalizedGlossaryKey(String source) =>
    source.trim().toLowerCase().split(RegExp(r'\s+')).join(' ');

/// Everything the player has written down, in the order they wrote it.
///
/// One list for every game, the way the cast is one list: a name belongs to
/// the game it came from, but the player owns both, and a second file per
/// game would mean saying "Fire in the hole!" again in each of them.
class Glossary {
  const Glossary({this.entries = const []});

  final List<GlossaryEntry> entries;

  static const empty = Glossary();

  bool get isEmpty => entries.isEmpty;

  Iterable<GlossaryEntry> of(GlossaryKind kind) => entries.where((entry) => entry.kind == kind);

  /// The entry matching [source] among the entries of [kind], or null.
  GlossaryEntry? match(GlossaryKind kind, String source) {
    final wanted = normalizedGlossaryKey(source);
    for (final entry in entries) {
      if (entry.kind == kind && entry.key == wanted) return entry;
    }
    return null;
  }

  /// [entry] written down, replacing whatever stood for the same source.
  ///
  /// The place in the list is kept when one is replaced: the player is
  /// usually correcting what they just added, and a line that jumps to the
  /// end while being edited is hard to follow.
  Glossary keeping(GlossaryEntry entry) {
    final kept = [...entries];
    final at = kept.indexWhere((one) => one.kind == entry.kind && one.key == entry.key);
    if (at < 0) {
      kept.add(entry);
    } else {
      kept[at] = entry;
    }
    return Glossary(entries: kept);
  }

  Glossary without(GlossaryKind kind, String source) {
    final wanted = normalizedGlossaryKey(source);
    return Glossary(
      entries: [
        for (final entry in entries)
          if (entry.kind != kind || entry.key != wanted) entry,
      ],
    );
  }

  /// What the worker is handed is the same shape the file holds: it reads
  /// the file when a session starts and is sent this when one is edited
  /// while a session runs, and one shape means one parser on that side.
  Map<String, Object?> toJson() => {
    'version': 1,
    'entries': [for (final entry in entries) entry.toJson()],
  };

  static Glossary fromJson(Object? value) {
    if (value is! Map) return empty;
    final written = value['entries'];
    if (written is! List) return empty;
    var glossary = empty;
    for (final one in written) {
      final entry = GlossaryEntry.fromJson(one);
      if (entry != null) glossary = glossary.keeping(entry);
    }
    return glossary;
  }
}
