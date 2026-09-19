// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// What a session of the Screen page reads off the screen.
///
/// One engine and one worker serve all three -- they differ only in what is
/// captured and which keys are registered -- so switching between them is a
/// session ended and another started, seconds rather than the minute a
/// worker takes to load.
enum ScreenReading {
  /// The subtitle frame reads itself while the session runs, and the key
  /// picks anything else on the screen out by hand.
  both,

  /// Only what the player picks out with the key. Nothing is scanned, so
  /// nothing is read until they ask for it.
  snippets,

  /// Only the subtitle frame, which is read as the game writes in it.
  subtitles;

  /// Whether the frame is scanned, which is what needs the game's window.
  bool get readsSubtitles => this != snippets;

  /// Whether the key that picks a snippet out is registered.
  bool get readsSnippets => this != subtitles;
}
