// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/app_settings.dart';
import '../../domain/session_config.dart';

/// Turns a process down to a share of its volume (`ld_set_process_volume`).
typedef VolumeSetter = int Function(int processId, double volume);

/// How far the game is turned down while it is dubbed, and when.
///
/// Two ways, one at a time: for the whole session, or -- with
/// [LineRules.duckWhileSpeaking] -- for the length of each line the dubbing
/// speaks, consecutive lines being one stretch. Only a named game is ever
/// turned down: the whole default output is captured as it plays. The game
/// gets its volume back when the session rests or ends, whichever duck took
/// it. This was spread over the repository (the session's duck, and again
/// on a resume) and the engine (the line's), which is how a stopped session
/// once left the game quiet for good.
///
/// A device that cannot be reached is no reason to refuse a line, a pause
/// or a start, so what the library answers is not checked.
class GameDucker {
  GameDucker({required this._setVolume, required this._restore});

  final VolumeSetter _setVolume;
  final void Function() _restore;

  CapturePlan? _capture;
  LineRules? _lines;

  /// Takes over the ducking for [config], turning the game down for the
  /// whole session where that is how it is done.
  void begin(SessionConfig config) {
    _capture = config.capture;
    _lines = config.lines;
    _duckSession();
  }

  /// The dubbing started or stopped speaking, where the game is turned down
  /// for a line rather than a session.
  ///
  /// The capture hears the game through this same volume, but a line being
  /// voiced now was recorded and recognized seconds ago -- what is turned
  /// down is what the player hears, not what the pipeline listens to. A line
  /// the game starts while the dubbing speaks is captured as quietly as it
  /// would have been under the session-long duck.
  void speaking({required bool speaking}) {
    final lines = _lines;
    final game = _capture?.processId ?? 0;
    if (lines == null || !lines.duckWhileSpeaking || game == 0) return;
    if (speaking) {
      _setVolume(game, lines.duckVolume);
    } else {
      _restore();
    }
  }

  /// The session rests: the game plays at its own volume meanwhile.
  void rest() => _restore();

  /// The session picks up where it rested, turned down as it started.
  void resume() => _duckSession();

  /// The session is over, and the game gets its volume back.
  void end() {
    _capture = null;
    _lines = null;
    _restore();
  }

  void _duckSession() {
    final capture = _capture;
    final lines = _lines;
    if (capture == null || lines == null || lines.duckWhileSpeaking) return;
    if (capture.processId == 0) return;
    // Turned down for the session only where it is the game's own sound
    // that is taken, or the screen that is read.
    if (!capture.mode.readsScreen && capture.audioSource != AudioCaptureSource.process) return;
    _setVolume(capture.processId, lines.duckVolume);
  }
}
