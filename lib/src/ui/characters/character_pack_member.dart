// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../domain/character.dart';
import '../common/pack_chip.dart';
import '../theme.dart';
import 'character_drag.dart';
import 'character_drag_card.dart';

/// A card inside a pack: its name, whether it carries a voice yet, and the
/// chip to drag it out by.
class CharacterPackMember extends StatelessWidget {
  const CharacterPackMember({
    super.key,
    required this.character,
    required this.packId,
    required this.onRemove,
  });

  final Character character;
  final String packId;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final voiced = character.vector.isNotEmpty;
    return PackChip<CharacterDrag>(
      data: CharacterDrag(character: character, fromPackId: packId),
      icon: voiced ? Icons.record_voice_over_outlined : Icons.mic_none_rounded,
      iconColor: voiced ? context.colors.success : context.colors.mutedInk,
      label: character.name,
      feedback: CharacterDragCard(name: character.name),
      onRemove: onRemove,
    );
  }
}
