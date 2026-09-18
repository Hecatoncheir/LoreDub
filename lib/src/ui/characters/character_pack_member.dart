// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/character.dart';
import '../theme.dart';
import 'character_drag.dart';
import 'character_drag_card.dart';

/// A card inside a pack: its name, a handle to drag it out by, and the
/// cross that takes it out without dragging.
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
    final l10n = AppLocalizations.of(context);
    final chip = Material(
      color: LoreDubPalette.raised,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        side: const BorderSide(color: LoreDubPalette.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              character.vector.isEmpty ? Icons.mic_none_rounded : Icons.record_voice_over_outlined,
              size: 16,
              color: character.vector.isEmpty ? LoreDubPalette.mutedInk : LoreDubPalette.success,
            ),
            const SizedBox(width: 8),
            Text(
              character.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            IconButton(
              tooltip: l10n.packsRemoveMember,
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 15),
              style: IconButton.styleFrom(
                minimumSize: const Size(26, 26),
                fixedSize: const Size(26, 26),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
    return Draggable<CharacterDrag>(
      data: CharacterDrag(character: character, fromPackId: packId),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: CharacterDragCard(name: character.name),
      childWhenDragging: Opacity(opacity: 0.4, child: chip),
      child: chip,
    );
  }
}
