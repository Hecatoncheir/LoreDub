// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// A character the player recorded and named, with the fingerprint their
/// voice is recognized by.
///
/// Unlike the voices a session founds by itself, these belong to the player
/// rather than to one game: the same actor speaks in every game they are
/// heard in, and a card can be handed to another player as a file.
class Character {
  const Character({
    required this.id,
    required this.name,
    required this.vector,
    this.gender,
    this.voice,
    this.seconds = 0,
    this.voicedBy,
  });

  factory Character.fromJson(Map<String, Object?> json) => Character(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    vector: [
      for (final value in json['vector'] as List<Object?>? ?? const [])
        if (value is num) value.toDouble(),
    ],
    gender: json['gender'] as String?,
    voice: json['voice'] as String?,
    seconds: (json['seconds'] as num?)?.toDouble() ?? 0,
    voicedBy: json['voicedBy'] as String?,
  );

  /// What the file keeps; the id is written so a card brought back after an
  /// edit replaces the card it came from rather than joining it.
  final String id;
  final String name;

  /// The voice fingerprint, as the converter's encoder measured it.
  final List<double> vector;

  /// What the recording sounded like, when it was clear enough to say.
  final String? gender;

  /// The Silero voice this character is read in, once one was given.
  final String? voice;

  /// How long the recording their fingerprint was taken from ran.
  final double seconds;

  /// The character whose voice reads this one, when the player asked for a
  /// substitution. It holds wherever this card is recognized, in every game,
  /// and one game's own choice in Live overrides it.
  ///
  /// One hop only: if that character is in turn read by a third, this card
  /// still gets the second one's voice. A chain would be a riddle, and two
  /// cards pointing at each other a loop.
  final String? voicedBy;

  /// Whether the card can be used at all: a name and a fingerprint.
  bool get isReady => name.trim().isNotEmpty && vector.isNotEmpty;

  Character copyWith({
    String? name,
    List<double>? vector,
    String? gender,
    bool clearGender = false,
    String? voice,
    bool clearVoice = false,
    double? seconds,
    String? voicedBy,
    bool clearVoicedBy = false,
  }) => Character(
    id: id,
    name: name ?? this.name,
    vector: vector ?? this.vector,
    gender: clearGender ? null : gender ?? this.gender,
    voice: clearVoice ? null : voice ?? this.voice,
    seconds: seconds ?? this.seconds,
    voicedBy: clearVoicedBy ? null : voicedBy ?? this.voicedBy,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'vector': vector,
    if (gender != null) 'gender': gender,
    if (voice != null) 'voice': voice,
    'seconds': seconds,
    if (voicedBy != null) 'voicedBy': voicedBy,
  };
}

/// The file every list of characters is written as — the whole list, or one
/// card on its way to another player. Reading one of these is what import
/// does, so a file holding a single character and a file holding twenty are
/// the same thing.
Map<String, Object?> charactersToJson(List<Character> characters) => {
  'version': 1,
  'characters': [for (final character in characters) character.toJson()],
};

/// The characters in [json], skipping anything that is not one. A file the
/// player edited by hand, or one from a newer version, gives back what it
/// can rather than nothing.
List<Character> charactersFromJson(Object? json) {
  final entries = switch (json) {
    {'characters': final List<Object?> list} => list,
    final List<Object?> list => list,
    _ => const <Object?>[],
  };
  return [
    for (final entry in entries)
      if (entry is Map<String, Object?>) Character.fromJson(entry),
  ].where((character) => character.isReady).toList();
}

/// [incoming] laid over [existing]: a card with an id already there replaces
/// it, keeping its place in the list, and the rest join the end.
///
/// Imported cards are matched by id rather than by name, so two players may
/// keep their own "Guard" and a card edited and sent back still lands on the
/// one it came from.
List<Character> mergeCharacters(List<Character> existing, List<Character> incoming) {
  final merged = [...existing];
  for (final character in incoming) {
    final at = merged.indexWhere((known) => known.id == character.id);
    if (at >= 0) {
      merged[at] = character;
    } else {
      merged.add(character);
    }
  }
  return merged;
}

/// A named group of characters the player can hand on as one file.
///
/// A pack holds ids rather than cards: the character stays in the cast, and
/// the pack says which of them belong together. The same character may be in
/// several packs, so a cast collected once can be handed out as "the tavern"
/// and as "chapter one" without being recorded twice.
class CharacterPack {
  const CharacterPack({required this.id, required this.name, this.characterIds = const []});

  factory CharacterPack.fromJson(Map<String, Object?> json) => CharacterPack(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    characterIds: [
      for (final value in json['characters'] as List<Object?>? ?? const [])
        if (value is String) value,
    ],
  );

  final String id;
  final String name;

  /// Who is in it, by [Character.id], in the order the player dropped them.
  final List<String> characterIds;

  bool holds(String characterId) => characterIds.contains(characterId);

  /// Whether the pack can be kept at all: an id and a name.
  bool get isReady => id.isNotEmpty && name.trim().isNotEmpty;

  CharacterPack copyWith({String? name, List<String>? characterIds}) => CharacterPack(
    id: id,
    name: name ?? this.name,
    characterIds: characterIds ?? this.characterIds,
  );

  /// [characterId] added at the end, or the pack itself when it is already
  /// there — dropping the same card twice changes nothing.
  CharacterPack withCharacter(String characterId) =>
      holds(characterId) ? this : copyWith(characterIds: [...characterIds, characterId]);

  CharacterPack withoutCharacter(String characterId) => holds(characterId)
      ? copyWith(
          characterIds: [
            for (final id in characterIds)
              if (id != characterId) id,
          ],
        )
      : this;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'characters': characterIds};
}

/// The whole library as one file: every card, and the packs they are grouped
/// into. Version 2 — a version 1 file has no packs and reads as a cast with
/// none, which is what every file written before packs existed is.
Map<String, Object?> characterLibraryToJson(
  List<Character> characters,
  List<CharacterPack> packs,
) => {
  'version': 2,
  'characters': [for (final character in characters) character.toJson()],
  'packs': [for (final pack in packs) pack.toJson()],
};

/// The packs in [json], skipping anything that is not one. A file from
/// before packs existed gives back none rather than failing to read.
List<CharacterPack> packsFromJson(Object? json) {
  final entries = switch (json) {
    {'packs': final List<Object?> list} => list,
    _ => const <Object?>[],
  };
  return [
    for (final entry in entries)
      if (entry is Map<String, Object?>) CharacterPack.fromJson(entry),
  ].where((pack) => pack.isReady).toList();
}

/// [incoming] laid over [existing] by id, the way [mergeCharacters] lays
/// cards over cards: a pack sent back after an edit lands on the one it came
/// from, and an unknown pack joins the end.
List<CharacterPack> mergePacks(List<CharacterPack> existing, List<CharacterPack> incoming) {
  final merged = [...existing];
  for (final pack in incoming) {
    final at = merged.indexWhere((known) => known.id == pack.id);
    if (at >= 0) {
      merged[at] = pack;
    } else {
      merged.add(pack);
    }
  }
  return merged;
}

/// The packs with every id that no longer names a character dropped, and a
/// card named twice kept once.
///
/// A pack outlives the cards in it — deleting a character leaves the packs
/// that held them alone — so the file is cleaned where it is read rather
/// than every place a character is removed.
List<CharacterPack> prunePacks(List<CharacterPack> packs, List<Character> characters) {
  final known = {for (final character in characters) character.id};
  return [
    for (final pack in packs)
      pack.copyWith(
        characterIds: [
          for (final id in pack.characterIds.toSet())
            if (known.contains(id)) id,
        ],
      ),
  ];
}

/// Everything the cast file holds: the cards the player recorded, and the
/// packs they are grouped into.
///
/// The two are read and written together because a pack means nothing
/// without the cards it names — an exported pack carries its characters, and
/// importing one adds them to the cast as well as the group.
class CharacterLibrary {
  const CharacterLibrary({this.characters = const [], this.packs = const []});

  /// What a missing or damaged file gives back.
  static const empty = CharacterLibrary();

  /// The library in [json], with packs cleaned of ids no card answers to.
  static CharacterLibrary fromJson(Object? json) {
    final characters = charactersFromJson(json);
    return CharacterLibrary(
      characters: characters,
      packs: prunePacks(packsFromJson(json), characters),
    );
  }

  final List<Character> characters;
  final List<CharacterPack> packs;

  Map<String, Object?> toJson() => characterLibraryToJson(characters, packs);
}
