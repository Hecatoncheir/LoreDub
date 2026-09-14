// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// The keys a session's speakers are known by, and who reads them.
///
/// A key is what the worker reports for a line — `character:<id>` for one of
/// the player's own cards, `timbre:<n>` for a voice the game's bank founded,
/// `voice:<name>` when nobody heard who was speaking. Whose voice reads whom
/// is the cast's own business: it is drawn on the graph and kept in the
/// cards, so there is nothing per game to read here.
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

/// The character whose voice reads [speaker], or null when the voice reads
/// itself.
///
/// Only a card can be given away, and only its own card says so
/// ([Character.voicedBy], which the graph draws): a voice of the game that
/// nobody has recorded is read as itself. The substitution is followed one
/// hop only, so two cards pointing at each other cannot spin.
String? readerOfSpeaker(String speaker, List<Character> characters) {
  final id = characterOfSpeaker(speaker);
  if (id == null) return null;
  for (final character in characters) {
    if (character.id == id) return character.voicedBy;
  }
  return null;
}
