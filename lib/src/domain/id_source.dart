// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// Names for the things the player adds: a card, a pack, a glossary entry,
/// a scheme on the shelf.
///
/// The clock in base 36 — short enough to read in a file, and never the
/// same twice. Two of them asked for in one microsecond, which is what a
/// pack and the card dropped into it amount to, would otherwise answer to
/// the same name, so the count never goes backwards inside one run.
///
/// The clock is a seam: a test that wants two ids in a row wants them
/// without waiting a microsecond for the second.
class IdSource {
  IdSource({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  int _last = 0;

  String next() {
    final now = _clock().microsecondsSinceEpoch;
    _last = now > _last ? now : _last + 1;
    return _last.toRadixString(36);
  }
}
