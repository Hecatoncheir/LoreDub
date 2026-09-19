// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/ui/graph/canvas/choice_fade.dart';

void main() {
  group('the field coming round to a choice', () {
    test('holds a card that is where it is going, and moves the one that is not', () {
      const fade = ChoiceFade(chosen: {'a'}, from: {'a': 0});

      expect(fade.of('a', 0), 0);
      expect(fade.of('a', 0.5), 0.5);
      expect(fade.of('a', 1), 1);
      // Never picked out and never moving: nothing at any moment of the run.
      expect(fade.of('b', 0.5), 0);
    });

    test('lets a card go as smoothly as it took it up', () {
      final fade = const ChoiceFade(chosen: {'a'}).towards(const {}, 1);

      expect(fade.of('a', 0), 1);
      expect(fade.of('a', 0.5), 0.5);
      expect(fade.of('a', 1), 0);
    });

    test('carries a choice made mid-run on from where it had got to', () {
      // 'a' is a third of the way in when the player picks 'b' as well.
      final started = const ChoiceFade().towards(const {'a'}, 1);
      final second = started.towards(const {'a', 'b'}, 1 / 3);

      expect(second.of('a', 0), closeTo(1 / 3, 0.001), reason: 'no jump back to nothing');
      expect(second.of('a', 1), 1);
      expect(second.of('b', 0), 0);
    });

    test('is settled once nothing is on its way, so the run can be let go of', () {
      expect(const ChoiceFade(chosen: {'a'}).settled, isTrue);
      expect(const ChoiceFade().towards(const {'a'}, 1).settled, isFalse);
      // A choice that changes nothing leaves nothing moving.
      expect(const ChoiceFade(chosen: {'a'}).towards(const {'a'}, 1).settled, isTrue);
    });
  });
}
