// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// Whose voice reads whom: the speakers a game's session hears, and the
/// character the player told LoreDub to read them in.
///
/// A key is what the worker reports for a line — `character:<id>` for one of
/// the player's own cards, `timbre:<n>` for a voice the game's bank founded
/// — and the value is the id of the character whose voice replaces theirs.
/// The map belongs to one game, because `timbre:<n>` numbers that game's
/// bank; a card assigned in one game keeps its own voice in another.
library;

import 'character.dart';

/// The prefix a speaker key carries when the line was matched to one of the
/// player's cards.
const characterSpeakerPrefix = 'character:';

/// The prefix of a voice the game's bank founded by itself.
const timbreSpeakerPrefix = 'timbre:';

/// The character [speaker] names, or null when the key is not one of the
/// player's cards.
String? characterOfSpeaker(String speaker) => speaker.startsWith(characterSpeakerPrefix)
    ? speaker.substring(characterSpeakerPrefix.length)
    : null;

/// Whether a voice can be replaced at all.
///
/// `voice:<name>` says nobody heard who was speaking — without the converter
/// the Silero voice is all that tells lines apart — and there is no identity
/// there to hang a replacement on.
bool isReplaceableSpeaker(String speaker) =>
    speaker.startsWith(characterSpeakerPrefix) || speaker.startsWith(timbreSpeakerPrefix);

/// The file a game's replacements are written as. Version 1 is the only one.
Map<String, Object?> speakerMapToJson(Map<String, String> replacements) => {
  'version': 1,
  'replacements': {...replacements},
};

/// The replacements in [json], skipping anything that is not a pair of
/// strings. A missing or damaged file gives back none, so a session starts
/// reading every voice as itself rather than refusing to start.
Map<String, String> speakerMapFromJson(Object? json) {
  final entries = switch (json) {
    {'replacements': final Map<Object?, Object?> map} => map,
    _ => const <Object?, Object?>{},
  };
  return {
    for (final entry in entries.entries)
      if (entry.key case final String speaker)
        if (entry.value case final String character)
          if (isReplaceableSpeaker(speaker) && character.isNotEmpty) speaker: character,
  };
}

/// The character whose voice reads [speaker], or null when the voice reads
/// itself.
///
/// This game's own choice answers first; a card that carries a standing
/// substitution ([Character.voicedBy]) answers after it, which is what lets
/// a character be given away before they have ever been heard. The
/// substitution is followed one hop only, so two cards pointing at each
/// other cannot spin.
String? readerOfSpeaker(
  String speaker,
  Map<String, String> replacements,
  List<Character> characters,
) {
  if (replacements[speaker] case final assigned?) return assigned;
  final id = characterOfSpeaker(speaker);
  if (id == null) return null;
  for (final character in characters) {
    if (character.id == id) return character.voicedBy;
  }
  return null;
}

/// [replacements] with [speaker] read in [character], or with the
/// replacement dropped when [character] is null.
Map<String, String> withReplacement(
  Map<String, String> replacements,
  String speaker,
  String? character,
) {
  final changed = {...replacements};
  if (character == null || character.isEmpty) {
    changed.remove(speaker);
  } else {
    changed[speaker] = character;
  }
  return changed;
}
