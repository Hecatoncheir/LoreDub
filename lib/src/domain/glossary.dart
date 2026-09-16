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

  /// A word of what was said, replaced by the player's. This is the one kind
  /// matched on the dubbing language rather than on English: the model is
  /// mostly steady about a name it renders -- over eight frames "Vault" came
  /// back as "Убежище" seven times, declined correctly each time -- but the
  /// eighth was "Хранилище", and nothing else here can reach that. The whole
  /// word is matched and nothing less: swapping a stem and carrying the
  /// ending over was measured turning "Восхищение сгорит" into "Восторге
  /// сгорит" and "Ворота Восхищения" into "Ворота Восторгя", because two
  /// words that mean the same thing need not decline the same way. Missing a
  /// declined form is a line said the way the model said it; inventing one
  /// is a word that does not exist, spoken aloud.
  word,
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

  /// What a pack names this entry by. [key] alone would not do: a name and a
  /// phrase may be written the same and are still two entries.
  String get packKey => '${kind.name}:$key';

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
      // By name rather than by a pair of questions, so a kind added later is
      // read back as itself rather than quietly as a name.
      kind: GlossaryKind.values.firstWhere(
        (kind) => kind.name == value['kind'],
        orElse: () => GlossaryKind.name,
      ),
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

/// What is punctuation at the edge of a line rather than part of it.
final _glossaryEdge = RegExp(
  r'''^[\s.!?,;:…"'«»“”\-–—]+|'''
  r'''[\s.!?,;:…"'«»“”\-–—]+$''',
);

/// The match key of [source]: what is compared rather than what is shown.
///
/// Case, spacing and the marks at either end say nothing here. Whisper
/// capitalizes a line by where it falls in a sentence, a shout comes back in
/// capitals, and the same shout arrives with a full stop as often as with an
/// exclamation -- an entry written under one spelling would miss the other.
/// The worker keeps the same rule, so both sides file a line under one key.
String normalizedGlossaryKey(String source) {
  final collapsed = source.trim().toLowerCase().split(RegExp(r'\s+')).join(' ');
  final trimmed = collapsed.replaceAll(_glossaryEdge, '');
  // A source that is punctuation and nothing else keeps what it had, rather
  // than filing every such entry under the empty string.
  return trimmed.isEmpty ? collapsed : trimmed;
}

/// A group of entries the player switches on and off as one.
///
/// It holds the keys of its entries rather than copies of them, so a line
/// corrected on the screen is corrected in every pack that names it. A pack
/// may hold all three kinds at once, and an entry may be in several packs --
/// a name belongs to a game and to a series both.
class GlossaryPack {
  const GlossaryPack({
    required this.id,
    required this.name,
    this.entryKeys = const [],
    this.active = false,
  });

  factory GlossaryPack.fromJson(Map<String, Object?> json) => GlossaryPack(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    entryKeys: [
      for (final value in json['entries'] as List<Object?>? ?? const [])
        if (value is String) value,
    ],
    active: json['active'] as bool? ?? false,
  );

  final String id;
  final String name;

  /// What is in it, by [GlossaryEntry.packKey], in the order it was dropped.
  final List<String> entryKeys;

  /// Whether the dubbing reads it. An active pack replaces the glossary
  /// rather than adding to it -- see [Glossary.inUse].
  final bool active;

  bool holds(String entryKey) => entryKeys.contains(entryKey);

  /// Whether the pack can be kept at all: an id and a name.
  bool get isReady => id.isNotEmpty && name.trim().isNotEmpty;

  GlossaryPack copyWith({String? name, List<String>? entryKeys, bool? active}) => GlossaryPack(
    id: id,
    name: name ?? this.name,
    entryKeys: entryKeys ?? this.entryKeys,
    active: active ?? this.active,
  );

  /// [entryKey] added at the end, or the pack itself when it is already
  /// there -- dropping the same entry twice changes nothing.
  GlossaryPack withEntry(String entryKey) =>
      holds(entryKey) ? this : copyWith(entryKeys: [...entryKeys, entryKey]);

  GlossaryPack withoutEntry(String entryKey) => holds(entryKey)
      ? copyWith(
          entryKeys: [
            for (final key in entryKeys)
              if (key != entryKey) key,
          ],
        )
      : this;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'entries': entryKeys,
    'active': active,
  };
}

/// Packs cleaned of keys no entry answers to, so a pack cannot go on naming
/// a line that was deleted while it was in it.
List<GlossaryPack> pruneGlossaryPacks(List<GlossaryPack> packs, List<GlossaryEntry> entries) {
  final known = {for (final entry in entries) entry.packKey};
  return [
    for (final pack in packs)
      pack.copyWith(
        entryKeys: [
          for (final key in pack.entryKeys.toSet())
            if (known.contains(key)) key,
        ],
      ),
  ];
}

/// Everything the player has written down, in the order they wrote it.
///
/// One list for every game, the way the cast is one list: a name belongs to
/// the game it came from, but the player owns both, and a second file per
/// game would mean saying "Fire in the hole!" again in each of them.
class Glossary {
  const Glossary({this.entries = const [], this.packs = const []});

  final List<GlossaryEntry> entries;

  /// The groups the entries are sorted into. Every entry stays in the lists
  /// above whether or not a pack names it: a pack is a way of reading the
  /// glossary, not a place entries are moved to.
  final List<GlossaryPack> packs;

  static const empty = Glossary();

  bool get isEmpty => entries.isEmpty;

  /// The packs the player has switched on.
  Iterable<GlossaryPack> get activePacks => packs.where((pack) => pack.active);

  /// What the dubbing is actually checked against.
  ///
  /// With no pack switched on this is everything written down. With one or
  /// more on, it is only what they hold: an active pack is the glossary of
  /// the session rather than an addition to it, so a pack made for one game
  /// can be switched on without another game's names reaching the line.
  /// Several may be on at once and what they hold adds together.
  ///
  /// The packs themselves are left out of the answer: this is what the
  /// worker is handed, and it has no use for a grouping it cannot act on.
  Glossary get inUse {
    final wanted = {for (final pack in activePacks) ...pack.entryKeys};
    if (wanted.isEmpty) return Glossary(entries: entries);
    return Glossary(
      entries: [
        for (final entry in entries)
          if (wanted.contains(entry.packKey)) entry,
      ],
    );
  }

  GlossaryPack? packWithId(String id) {
    for (final pack in packs) {
      if (pack.id == id) return pack;
    }
    return null;
  }

  /// The packs holding [entry], so the screen can show where it is filed.
  Iterable<GlossaryPack> packsHolding(GlossaryEntry entry) =>
      packs.where((pack) => pack.holds(entry.packKey));

  /// [pack] kept, replacing the one of the same id. Its place in the list is
  /// kept, the way an entry's is: a pack renamed must not jump to the end.
  Glossary keepingPack(GlossaryPack pack) {
    final kept = [...packs];
    final at = kept.indexWhere((one) => one.id == pack.id);
    if (at < 0) {
      kept.add(pack);
    } else {
      kept[at] = pack;
    }
    return Glossary(entries: entries, packs: kept);
  }

  /// The pack taken off the shelf. The entries it named stay written down --
  /// a pack is a grouping, and deleting one must not delete the glossary.
  Glossary withoutPack(String packId) => Glossary(
    entries: entries,
    packs: [
      for (final pack in packs)
        if (pack.id != packId) pack,
    ],
  );

  /// [entry] dropped into the pack, and taken out of the one it was dragged
  /// from when it came from one.
  Glossary filing(GlossaryEntry entry, {required String into, String? from}) {
    var moved = this;
    if (from != null && from != into) moved = moved.unfiling(entry, from: from);
    final pack = moved.packWithId(into);
    if (pack == null) return moved;
    return moved.keepingPack(pack.withEntry(entry.packKey));
  }

  Glossary unfiling(GlossaryEntry entry, {required String from}) {
    final pack = packWithId(from);
    if (pack == null) return this;
    return keepingPack(pack.withoutEntry(entry.packKey));
  }

  /// The pack and what it names, as a file of its own: exporting a pack
  /// carries its entries, since a list of keys would mean nothing on another
  /// machine. It travels switched off, whatever it was here -- a pack that
  /// arrived already replacing the glossary would be a surprise.
  Glossary onlyPack(String packId) {
    final pack = packWithId(packId);
    if (pack == null) return empty;
    final wanted = pack.entryKeys.toSet();
    return Glossary(
      entries: [
        for (final entry in entries)
          if (wanted.contains(entry.packKey)) entry,
      ],
      packs: [pack.copyWith(active: false)],
    );
  }

  /// Switches a pack on or off. Several may be on at once.
  Glossary activating(String packId, {required bool active}) {
    final pack = packWithId(packId);
    if (pack == null) return this;
    return keepingPack(pack.copyWith(active: active));
  }

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
    return Glossary(entries: kept, packs: packs);
  }

  Glossary without(GlossaryKind kind, String source) {
    final wanted = normalizedGlossaryKey(source);
    final gone = '${kind.name}:$wanted';
    return Glossary(
      entries: [
        for (final entry in entries)
          if (entry.kind != kind || entry.key != wanted) entry,
      ],
      // A pack must not go on naming a line that is no longer written down.
      packs: [for (final pack in packs) pack.withoutEntry(gone)],
    );
  }

  /// What the worker is handed is the same shape the file holds: it reads
  /// the file when a session starts and is sent this when one is edited
  /// while a session runs, and one shape means one parser on that side.
  Map<String, Object?> toJson() => {
    'version': 2,
    'entries': [for (final entry in entries) entry.toJson()],
    'packs': [for (final pack in packs) pack.toJson()],
  };

  /// Reads a file of either version: one written before packs existed has no
  /// `packs` key and comes back as entries in no pack, which is what it was.
  static Glossary fromJson(Object? value) {
    if (value is! Map) return empty;
    final written = value['entries'];
    if (written is! List) return empty;
    var glossary = empty;
    for (final one in written) {
      final entry = GlossaryEntry.fromJson(one);
      if (entry != null) glossary = glossary.keeping(entry);
    }
    final grouped = <GlossaryPack>[];
    for (final one in value['packs'] as List<Object?>? ?? const []) {
      if (one is! Map) continue;
      final pack = GlossaryPack.fromJson(one.cast<String, Object?>());
      if (pack.isReady) grouped.add(pack);
    }
    return Glossary(
      entries: glossary.entries,
      packs: pruneGlossaryPacks(grouped, glossary.entries),
    );
  }
}
