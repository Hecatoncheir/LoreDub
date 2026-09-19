// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/foundation.dart';

/// What a character tile can be asked to do. A null one is a button the tile
/// draws and leaves off.
@immutable
class CharacterTileActions {
  const CharacterTileActions({
    required this.onRename,
    required this.onDelete,
    this.onRecord,
    this.onPlay,
    this.onPreview,
    this.onStopSound,
    this.onExport,
    this.onFilesDropped,
  });

  final ValueChanged<String> onRename;
  final VoidCallback onDelete;

  /// Null while another card records, or while no session runs.
  final VoidCallback? onRecord;

  /// Plays back what this card was recorded from. Null when the card has no
  /// clip of its own — an imported one carries the fingerprint and no audio.
  final VoidCallback? onPlay;

  /// Speaks a line in the voice the dubbing would read this card in. Null
  /// while the speech model is missing, while anything else sounds, or while
  /// something else holds the worker.
  final VoidCallback? onPreview;

  /// Ends what is sounding, whichever of the two started it.
  final VoidCallback? onStopSound;

  /// Null while the card holds no voice worth writing to a file.
  final VoidCallback? onExport;

  /// Takes the recordings dropped onto the card and measures its voice from
  /// all of them at once. Null while nothing could be measured — the
  /// converter is missing, or another card is being recorded.
  final ValueChanged<List<String>>? onFilesDropped;
}
