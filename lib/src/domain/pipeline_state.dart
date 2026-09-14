// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// [paused] is a live session resting: the models stay loaded and capture
/// stays open, so resuming takes no startup at all.
enum PipelineStatus { idle, starting, listening, paused, stopping, error }

/// Which session holds the worker: live dubbing of the game; the snapshot
/// session, which loads only the translator and the voice and waits for the
/// player to select an area of the screen; the scene session, which loads
/// only the converter and places the voices of a game without dubbing them;
/// the characters session, which the characters screen records a card's
/// voice through; or the preview session, which loads the speech model and
/// the converter to play a sample of one card's voice.
///
/// The engine runs one of them at a time and says on every state event which
/// one it is running, so that a screen never reads another's session as its
/// own.
enum PipelineSession { live, screen, scene, characters, preview }

class TranscriptEntry {
  const TranscriptEntry({
    required this.original,
    required this.english,
    required this.translated,
    required this.latency,
    this.speaker,
  });

  final String original;
  final String english;
  final String translated;
  final Duration latency;

  /// Who the worker heard: `character:<id>` for one of the player's cards,
  /// `timbre:<n>` for a voice the game's bank founded, `voice:<name>` when
  /// nothing could tell the speakers apart. Null in a snapshot, which is
  /// read off the screen and has no voice at all.
  final String? speaker;
}

/// A voice this session has heard, as the scene list shows it.
///
/// The key is what the worker reports, and what an assignment is made
/// against; the line is the last thing they said, so the player can tell who
/// is who without knowing what `timbre:2` means.
class SceneSpeaker {
  const SceneSpeaker({required this.key, this.line = '', this.lines = 1, this.seconds = 0});

  final String key;

  /// The last thing they said, once there is a dubbing session to say it.
  /// Empty while the voices are only being placed, which needs no words.
  final String line;

  /// How many lines this voice has said, so a passer-by is easy to tell from
  /// the character of the scene.
  final int lines;

  /// The longest phrase heard from them, which is what a row shows when
  /// there are no words yet.
  final double seconds;

  /// This voice heard once more. The longest phrase stands rather than the
  /// last, the way a character card keeps its clearest line.
  SceneSpeaker heard({String? line, double? seconds}) => SceneSpeaker(
    key: key,
    line: line == null || line.isEmpty ? this.line : line,
    lines: lines + 1,
    seconds: seconds == null || seconds < this.seconds ? this.seconds : seconds,
  );
}
