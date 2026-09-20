// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../common/committed_text_field.dart';
import '../common/hover_grow.dart';
import '../common/tile_edge.dart';
import '../theme.dart';
import 'character_tile_action_bar.dart';
import 'character_tile_actions.dart';
import 'character_tile_lines.dart';
import 'character_tile_model.dart';

/// The card itself: a name to type in, the lines saying what it carries, and
/// the buttons along its foot.
class CharacterTileBody extends StatelessWidget {
  const CharacterTileBody({
    super.key,
    required this.model,
    required this.actions,
    required this.lit,
  });

  final CharacterTileModel model;
  final CharacterTileActions actions;

  /// Files are held over the card.
  final bool lit;

  /// Files held over the card say so the way a recording does: the whole
  /// card is the target, so the whole edge lights up.
  bool get _edged => lit || model.recording || model.building;

  @override
  Widget build(BuildContext context) => HoverGrow(
    alignment: Alignment.center,
    scale: 1.02,
    builder: (context, hovered) => Material(
      color: context.colors.panel,
      clipBehavior: Clip.antiAlias,
      shape: TileEdge.of(context.colors, marked: _edged, hovered: hovered).shaped(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: CommittedTextField(
              value: model.character.name,
              onCommitted: actions.onRename,
              style: context.textStyles.cardTitle,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).charactersNameLabel,
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: CharacterTileLines(model: model),
            ),
          ),
          SizedBox(
            height: 44,
            child: CharacterTileActionBar(model: model, actions: actions),
          ),
        ],
      ),
    ),
  );
}
