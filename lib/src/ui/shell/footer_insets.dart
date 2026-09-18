// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// How the foot of the sidebar is laid out: the version's button and the
/// update line below it.
abstract final class FooterInsets {
  /// Where the foot begins: the version's icon and the status line below it
  /// both start here. The button's own padding makes up the difference, so
  /// the two stay in step if either is adjusted.
  static const start = outer + button;
  static const outer = 8.0;
  static const button = 4.0;
  static const iconSize = 14.0;
}
