// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../l10n/app_localizations.dart';
import '../domain/character.dart';
import '../domain/speaker_keys.dart';

/// What to call a voice the session heard.
///
/// A card the player recorded answers by name; a voice the game's bank
/// founded has only its number, and a line nobody could place has not even
/// that. The wording lives here rather than in the domain, which holds keys.
String speakerName(AppLocalizations l10n, String speaker, List<Character> characters) {
  if (characterOfSpeaker(speaker) case final id?) {
    for (final character in characters) {
      if (character.id == id) return character.name;
    }
    // A card deleted since the line was spoken.
    return l10n.sceneVoiceAnonymous;
  }
  if (speaker.startsWith(timbreSpeakerPrefix)) {
    final number = int.tryParse(speaker.substring(timbreSpeakerPrefix.length));
    // The bank counts from zero; the player counts from one.
    if (number != null) return l10n.sceneVoiceUnknown(number + 1);
  }
  return l10n.sceneVoiceAnonymous;
}

/// The name of the character [speaker] is actually read in, or null when it
/// is read as itself.
///
/// There is one source for that: the card the graph gave this one away to.
String? replacementName(String speaker, List<Character> characters) {
  final id = readerOfSpeaker(speaker, characters);
  if (id == null) return null;
  for (final character in characters) {
    if (character.id == id) return character.name;
  }
  return null;
}
