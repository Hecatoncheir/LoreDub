// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// Where the live screen changes its arrangement, measured on the window it
/// is given.
abstract final class LiveLayout {
  /// What the live screen keeps for itself before it starts scrolling: the two
  /// cards at their tallest, and a transcript still worth looking at under
  /// them.
  static const minHeight = 640.0;

  /// Beyond this the scene voices sit beside the transcript rather than under
  /// it; below it the transcript would be left too narrow to read.
  static const sceneBesideTranscriptWidth = 1000.0;
  static const sceneVoicesWidth = 340.0;

  /// Under this the stacked layout shows the transcript alone.
  static const sceneStackedMinHeight = 360.0;

  /// The narrowest card that still fits the source switch, the process picker
  /// and the language block side by side.
  ///
  /// Measured rather than derived: the switch is as wide as its translated
  /// labels make it, so arithmetic over the fixed parts guessed low. What the
  /// row actually needs came to about 920 plus
  /// [minimumProcessPickerWidth] for the picker. Below this the picker was
  /// squeezed to a stub and broke its label mid-word, so the stacked
  /// arrangement takes over and hands it the full width. The widget test walks
  /// a range of window sizes to keep this honest.
  static const wideSourceRowWidth = 920 + minimumProcessPickerWidth;

  /// Enough for a process name beside the refresh button.
  static const minimumProcessPickerWidth = 320.0;
}
