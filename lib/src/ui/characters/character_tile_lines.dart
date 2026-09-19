// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../theme.dart';
import 'character_tile_line.dart';
import 'character_tile_model.dart';
import 'character_tile_texts.dart';

/// What the card carries, a line each.
///
/// Every line gives way rather than spilling: a card may say what was
/// recorded, whose voice reads it and which packs it belongs to at once, and
/// a narrow window wraps them.
class CharacterTileLines extends StatelessWidget {
  const CharacterTileLines({super.key, required this.model});

  final CharacterTileModel model;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final texts = CharacterTileTexts(l10n, model);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CharacterTileLine(
          text: texts.voice(),
          color: model.recording ? LoreDubPalette.orange : LoreDubPalette.mutedInk,
          bold: model.recording,
          maxLines: 2,
        ),
        if (model.building || model.built != null)
          CharacterTileLine(
            text: texts.building(),
            top: 6,
            color: model.built?.together == false ? LoreDubPalette.error : LoreDubPalette.orange,
            bold: true,
            maxLines: 2,
          ),
        if (model.character.voicedBy != null)
          CharacterTileLine(
            text: l10n.sceneVoiceReplaced(model.readerName ?? l10n.sceneVoiceAnonymous),
            top: 6,
            color: LoreDubPalette.orange,
            bold: true,
          ),
        // A rigid gap rather than a padding inside the line: the lines give
        // way when the card is short, and the space between them should not.
        if (model.packNames.isNotEmpty) ...[
          const SizedBox(height: 6),
          CharacterTileLine(text: l10n.charactersInPacks(model.packNames.join(', '))),
        ],
      ],
    );
  }
}
