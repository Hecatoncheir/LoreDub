// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/foundation.dart';

import '../../domain/built_voice.dart';
import '../../domain/character.dart';

/// Everything a character tile shows, decided before it is drawn.
@immutable
class CharacterTileModel {
  const CharacterTileModel({
    required this.character,
    this.recording = false,
    this.heardSeconds = 0,
    this.packNames = const [],
    this.packs = const [],
    this.readerName,
    this.playing = false,
    this.previewing = false,
    this.carriesTimbre = true,
    this.dubbing = false,
    this.building = false,
    this.built,
  });

  final Character character;

  /// This card is the one the session is listening for.
  final bool recording;

  /// How much speech the recording has kept, while it is recording.
  final double heardSeconds;

  /// The packs holding this card, named under it so the player can see where
  /// a card already belongs without opening every pack.
  final List<String> packNames;

  /// Every pack on the shelf, which the card's menu offers to file it in.
  final List<CharacterPack> packs;

  /// The name of the card reading this one, when one does. Who reads whom is
  /// drawn on the graph; a card shows it and does not set it.
  final String? readerName;

  /// Whether this card's clip is sounding right now.
  final bool playing;

  /// Whether this card's sample is being got ready or spoken.
  final bool previewing;

  /// Whether the sample will be spoken in the character's own timbre.
  /// Without Original voice the dubbing reads them in a plain synthesized
  /// voice, and a sample that says so is worth more than one that leaves the
  /// player wondering where the voice they recorded went.
  final bool carriesTimbre;

  /// Whether a dubbing session holds the worker, which is what the sample
  /// waits for. The button says so, rather than sending the player after a
  /// speech model they already have.
  final bool dubbing;

  /// Whether this card's voice is being measured from dropped files.
  final bool building;

  /// What came of the last such measurement on this card, while the screen
  /// still has it to show.
  final BuiltVoice? built;
}
