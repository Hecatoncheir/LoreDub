// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../models/model_action.dart';
import '../models/model_action_button.dart';
import 'character_card_menu.dart';
import 'character_tile_actions.dart';
import 'character_tile_model.dart';
import 'character_tile_texts.dart';

/// The buttons along the foot of a character tile: record, hear the clip back,
/// hear the dubbing's voice, and the menu with the rest.
class CharacterTileActionBar extends StatelessWidget {
  const CharacterTileActionBar({super.key, required this.model, required this.actions});

  final CharacterTileModel model;
  final CharacterTileActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final texts = CharacterTileTexts(l10n, model);
    final id = model.character.id;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ModelActionButton(
          onDark: false,
          action: ModelAction(
            icon: model.recording ? Icons.stop_rounded : Icons.mic_rounded,
            tooltip: model.recording ? l10n.charactersRecordStop : l10n.charactersRecord,
            onPressed: actions.onRecord,
          ),
        ),
        // Hear back what the card was taken from: the surest way to tell
        // whether the right character was caught. The same button stops it —
        // a recording may run for three minutes, and nobody wants to sit
        // through one.
        ModelActionButton(
          key: ValueKey('playClip-$id'),
          onDark: false,
          action: ModelAction(
            icon: model.playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
            tooltip: texts.playTooltip(canPlay: actions.onPlay != null),
            onPressed: model.playing ? actions.onStopSound : actions.onPlay,
          ),
        ),
        // Not the recording but the dubbing: the voice this card will be read
        // in, with its own timbre over it.
        ModelActionButton(
          key: ValueKey('previewVoice-$id'),
          onDark: false,
          action: ModelAction(
            icon: model.previewing ? Icons.stop_rounded : Icons.record_voice_over_rounded,
            tooltip: texts.previewTooltip(canPreview: actions.onPreview != null),
            onPressed: model.previewing ? actions.onStopSound : actions.onPreview,
          ),
        ),
        // Saving the card and throwing it away are neither of them about the
        // voice, and one of them cannot be taken back. Five unlabelled icons in
        // a row put delete a slip away from record; behind a menu it is named
        // in words and reached on purpose.
        CharacterCardMenu(
          characterId: id,
          onExport: actions.onExport,
          onDelete: actions.onDelete,
          packs: model.packs,
          onFileInPack: actions.onFileInPack,
        ),
      ],
    );
  }
}
