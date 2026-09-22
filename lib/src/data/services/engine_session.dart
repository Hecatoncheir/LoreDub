// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/pipeline_state.dart';
import '../../domain/session_config.dart';

/// Everything that belongs to one run of the engine, from its start to its
/// stop.
///
/// Kept in one object rather than in fields of the engine reset by hand,
/// so a stop cannot forget one and a start begins with none of the last
/// run's left over. It is also what a phrase checks before it is published:
/// work begun under one run that finishes under another -- the stop landed
/// while the worker was answering, and the next session came up -- is
/// dropped rather than shown and voiced in a session that never heard it.
class EngineSession {
  EngineSession(this.config);

  /// What the run was started with, kept in step with what is changed
  /// under it: the voice, the cut, the subtitle frame.
  SessionConfig config;

  /// Which session this is, which every event it sends is named with.
  PipelineSession get kind => config.session;

  /// Whether the run is up: the capture started, or the worker ready where
  /// nothing is captured. Before that it is still starting.
  bool running = false;

  /// Whether the run rests: capture hands nothing on, and a line finishing
  /// its translation meanwhile is shown but not voiced.
  bool paused = false;

  /// What subtitle mode read last, so a line that grows in place is voiced
  /// only for what it gained, and one that comes back unchanged -- even
  /// after leaving the screen -- is not voiced again.
  String? previousOcrText;

  /// What the interface was last told, so each is said once.
  String? reportedLanguage;
  String? reportedVoice;
  int? reportedBankSize;

  /// The game's sound as it was last heard, while a screen session follows
  /// the voices, and the ones a line still waiting is to be coloured with.
  String? voiceHeard;
  final voicesInUse = <String>{};
}
