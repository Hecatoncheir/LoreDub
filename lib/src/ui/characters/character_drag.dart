// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/character.dart';

/// A card on its way from one place to another: which character, and the
/// pack it was picked up from, if it was picked up from one.
///
/// The pack is what tells a drop onto the cast from a drop onto a pack: the
/// first takes the card out of where it came from, the second only adds it.
class CharacterDrag {
  const CharacterDrag({required this.character, this.fromPackId});

  final Character character;
  final String? fromPackId;
}
