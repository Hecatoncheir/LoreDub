// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../../domain/sound_files.dart';
import 'character_drag.dart';
import 'character_drag_card.dart';
import 'character_tile_actions.dart';
import 'character_tile_body.dart';
import 'character_tile_model.dart';

/// One character: the name to edit, what was recorded for them, and the
/// buttons that record it, hand it on or throw the card away.
///
/// Drawn in the model tiles' vocabulary — a panel with an orange edge while
/// it is the one being recorded, and its buttons along the foot — and picked
/// up by the pointer, so a card can be dropped into a pack. What it shows is
/// its [model] and what it can do its [actions]; it decides neither.
class CharacterTile extends StatefulWidget {
  const CharacterTile({super.key, required this.model, required this.actions, this.fromPackId});

  final CharacterTileModel model;
  final CharacterTileActions actions;

  /// Set when the card is drawn inside a pack, so dropping it on the cast
  /// takes it out of that pack.
  final String? fromPackId;

  @override
  State<CharacterTile> createState() => _CharacterTileState();
}

class _CharacterTileState extends State<CharacterTile> {
  /// Whether files are being held over this card right now.
  bool _over = false;

  void _takeFiles(DropDoneDetails details) {
    setState(() => _over = false);
    final sound = soundAmong(details.files.map((file) => file.path));
    if (sound.isNotEmpty) widget.actions.onFilesDropped?.call(sound);
  }

  @override
  Widget build(BuildContext context) {
    final character = widget.model.character;
    final tile = CharacterTileBody(model: widget.model, actions: widget.actions, lit: _over);
    // The whole card takes the files, not a strip of it: what the player
    // aims at is the character, and a card is small enough already.
    return DropTarget(
      onDragEntered: (_) => setState(() => _over = true),
      onDragExited: (_) => setState(() => _over = false),
      onDragDone: _takeFiles,
      child: Draggable<CharacterDrag>(
        data: CharacterDrag(character: character, fromPackId: widget.fromPackId),
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: CharacterDragCard(name: character.name),
        childWhenDragging: Opacity(opacity: 0.4, child: tile),
        child: tile,
      ),
    );
  }
}
