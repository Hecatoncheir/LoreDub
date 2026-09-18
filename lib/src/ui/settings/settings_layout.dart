// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// How the settings page is spaced and where it changes its arrangement.
abstract final class SettingsLayout {
  /// Beyond this two setting cards stand side by side rather than one under
  /// the other. Below it a slider and its own notes would be squeezed.
  static const pairedCardsWidth = 900.0;

  /// How far one group of settings stands from the next: enough more than
  /// the 12 between cards that the break is read as a break rather than a
  /// gap.
  static const groupGap = 28.0;

  /// The gap between two cards of one group.
  static const cardGap = 12.0;
}
