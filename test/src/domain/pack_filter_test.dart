// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/pack_filter.dart';

void main() {
  test('shows every pack while nothing is typed', () {
    expect(PackFilter().filtering, isFalse);
    expect(PackFilter('   ').shows('Fallout 4'), isTrue, reason: 'spaces are nothing typed');
  });

  test('shows a pack whose name holds what is typed, whatever the case', () {
    final filter = PackFilter(' FALL ');

    expect(filter.filtering, isTrue);
    expect(filter.shows('Fallout 4'), isTrue);
    expect(filter.shows('New Vegas: Fallout'), isTrue, reason: 'anywhere in the name');
    expect(filter.shows('Боевые крики'), isFalse);
    expect(PackFilter('крик').shows('Боевые КРИКИ'), isTrue);
  });
}
