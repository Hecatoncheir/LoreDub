// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// Where the screen session's page changes its arrangement, measured on the
/// window it is given.
abstract final class ScreenLayout {
  /// Narrower than this the start button goes under the game picker rather
  /// than beside it, which would squeeze the picker to a stub.
  static const startBesidePickerWidth = 760.0;

  /// What the screen session keeps for itself before it starts scrolling: the
  /// controls beside the frame, and a list under them worth looking at.
  static const minHeight = 980.0;

  /// The same, with the frame under the controls rather than beside them.
  static const stackedMinHeight = 1320.0;

  /// How tall one of the two lists is made when the screen scrolls instead of
  /// filling the window.
  static const listHeight = 320.0;

  /// Beyond this the subtitle frame stands beside the controls rather than
  /// under them.
  static const frameBesideControlsWidth = 860.0;

  static const frameCardWidth = 380.0;

  /// Narrower than this the voice goes under the language rather than
  /// beside it: the language row takes 512, and a voice's name wants 240.
  static const voiceBesideLanguageWidth = 780.0;
}
