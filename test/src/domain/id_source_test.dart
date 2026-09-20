// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/id_source.dart';

void main() {
  test('two names asked for in the same microsecond are still two', () {
    // A pack and the card dropped into it: one gesture, one reading of the
    // clock, and two things that must not answer to the same name.
    final stopped = DateTime.utc(2026, 9, 20);
    final ids = IdSource(clock: () => stopped);

    final minted = [for (var count = 0; count < 3; count++) ids.next()];

    expect(minted.toSet(), hasLength(3));
  });

  test('a name is short enough to read in a file', () {
    final ids = IdSource(clock: () => DateTime.utc(2026, 9, 20));

    // Base 36 of the microseconds: eleven characters, not twenty digits.
    expect(ids.next(), matches(RegExp(r'^[0-9a-z]{1,12}$')));
  });

  test('never goes backwards, whatever the clock does', () {
    var now = DateTime.utc(2026, 9, 20, 12);
    final ids = IdSource(clock: () => now);

    final first = ids.next();
    // The clock stepping back -- a time zone, a correction -- must not hand
    // out a name that was used already.
    now = DateTime.utc(2026, 9, 20, 11);
    final second = ids.next();

    expect(second, isNot(first));
    expect(int.parse(second, radix: 36), greaterThan(int.parse(first, radix: 36)));
  });
}
