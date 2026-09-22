// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// Keeping a value in a list the way every list of the player's is kept.
extension Upserting<T> on List<T> {
  /// This list with [value] in place of the one [same] finds -- in its
  /// place, since a card renamed or a line being corrected must not jump to
  /// the end while the player works on it -- or at the end when there is
  /// none.
  List<T> upserting(T value, bool Function(T kept) same) {
    final kept = [...this];
    final at = kept.indexWhere(same);
    if (at < 0) {
      kept.add(value);
    } else {
      kept[at] = value;
    }
    return kept;
  }
}
