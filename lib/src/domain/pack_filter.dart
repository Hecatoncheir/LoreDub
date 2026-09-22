// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// What a shelf of packs is narrowed to: a part of a name, as the player
/// typed it. The same on both shelves, the cast's and the glossary's, where
/// a player who keeps a pack for every game soon has more of them than fit
/// on the screen.
class PackFilter {
  PackFilter([String typed = '']) : looking = typed.trim().toLowerCase();

  /// What is looked for, trimmed and lower-cased.
  final String looking;

  bool get filtering => looking.isNotEmpty;

  /// Whether a pack called [name] is shown: every one while nothing is
  /// typed, and otherwise one whose name holds what was, whatever the case.
  bool shows(String name) => !filtering || name.toLowerCase().contains(looking);
}
