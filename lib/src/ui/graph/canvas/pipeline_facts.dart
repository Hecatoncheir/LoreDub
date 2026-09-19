// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../../domain/app_settings.dart';
import '../../../domain/character.dart';
import '../../../domain/compute_device.dart';
import '../../../domain/game_process.dart';
import '../../../domain/model_selection.dart';

/// What the nodes write on themselves. The canvas draws the pipeline as it
/// is configured, so it is handed the configuration rather than four cubits.
class PipelineFacts {
  const PipelineFacts({
    required this.settings,
    required this.selection,
    this.process,
    this.characters = const [],
    this.activeBackends = const {},
    this.running = false,
    this.paused = false,
    this.recordingVoice = false,
  });

  final AppSettings settings;
  final ModelSelection selection;
  final GameProcess? process;
  final List<Character> characters;

  /// What a running session reported it actually settled on.
  final Map<ComputeStage, ComputeBackend> activeBackends;
  final bool running;

  /// Whether that session is resting. The cast may be rewired either way;
  /// this is only so the toolbar can offer to wake it.
  final bool paused;

  /// Whether a card is being recorded on the characters screen. That session
  /// listens to the game it started with, and the game is one choice shared
  /// by every screen — so it is not to be changed from here either, idle as
  /// the pipeline itself is.
  final bool recordingVoice;

  Character? character(String? id) {
    if (id == null) return null;
    for (final character in characters) {
      if (character.id == id) return character;
    }
    return null;
  }

  ComputeBackend backendOf(ComputeStage stage, ComputeAvailability availability) =>
      activeBackends[stage] ?? settings.backendFor(stage, availability);
}
