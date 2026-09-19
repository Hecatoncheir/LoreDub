// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../common/committed_text_field.dart';
import '../common/hover_grow.dart';
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

  Color _edge({required bool hovered}) {
    if (_edged) return LoreDubPalette.orange;
    return hovered ? LoreDubPalette.ink : LoreDubPalette.outline;
  }

  @override
  Widget build(BuildContext context) => HoverGrow(
    alignment: Alignment.center,
    scale: 1.02,
    builder: (context, hovered) => Material(
      color: LoreDubPalette.panel,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        side: BorderSide(
          color: _edge(hovered: hovered),
          width: _edged ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: CommittedTextField(
              value: model.character.name,
              onCommitted: actions.onRename,
              style: const TextStyle(
                fontFamily: LoreDubFonts.display,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
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
