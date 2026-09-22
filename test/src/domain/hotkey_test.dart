// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/hotkey.dart';

void main() {
  test('writes a combination the way Windows does', () {
    const hotkey = Hotkey(keyCode: 0x50, label: 'P', control: true, alt: true, shift: true);

    expect(hotkey.display, 'Ctrl + Alt + Shift + P');
    expect(hotkey.keys, ['Ctrl', 'Alt', 'Shift', 'P'], reason: 'one key each, as drawn');
    // MOD_ALT | MOD_CONTROL | MOD_SHIFT.
    expect(hotkey.modifiers, 0x7);
  });

  test('keeps letters behind Ctrl, Alt or Win so the game keeps them', () {
    expect(const Hotkey(keyCode: 0x4B, label: 'K').leavesGameKeys, isFalse);
    expect(const Hotkey(keyCode: 0x4B, label: 'K', shift: true).leavesGameKeys, isFalse);
    expect(const Hotkey(keyCode: 0x4B, label: 'K', alt: true).leavesGameKeys, isTrue);
    expect(const Hotkey(keyCode: 0x4B, label: 'K', win: true).leavesGameKeys, isTrue);
    expect(const Hotkey(keyCode: 0x78, label: 'F9').leavesGameKeys, isTrue, reason: 'F9');
    expect(const Hotkey(keyCode: 0x13, label: 'Pause').leavesGameKeys, isTrue);
  });

  test('survives being stored', () {
    const hotkey = Hotkey(keyCode: 0xBA, label: ';', control: true, win: true);

    expect(Hotkey.decode(hotkey.encode()), hotkey);
    expect(Hotkey.decode(''), isNull);
    expect(Hotkey.decode('nonsense'), isNull);
    expect(Hotkey.decode('0:2:P'), isNull, reason: 'no key');
  });

  test('tells the same combination apart from its label', () {
    const pause = Hotkey(keyCode: 0x50, label: 'P', control: true);

    expect(pause.sameCombination(const Hotkey(keyCode: 0x50, label: 'p', control: true)), isTrue);
    expect(pause.sameCombination(const Hotkey(keyCode: 0x50, label: 'P', alt: true)), isFalse);
  });

  group('binding a combination', () {
    const pause = Hotkey.defaultPause;

    test('refuses one that takes a key from the game', () {
      const bare = Hotkey(keyCode: 0x50, label: 'P');

      expect(bindingProblem(bare, const {}), isA<HotkeyTakesGameKey>());
    });

    test('names the action that already holds it', () {
      final problem = bindingProblem(pause, const {
        HotkeyAction.resume: Hotkey.defaultResume,
        HotkeyAction.frame: Hotkey(keyCode: 0x50, label: 'P', control: true, alt: true),
      });

      expect(
        problem,
        isA<HotkeyAlreadyBound>().having((p) => p.action, 'action', HotkeyAction.frame),
      );
    });

    test('lets a free combination through, unbound actions included', () {
      expect(bindingProblem(pause, const {HotkeyAction.resume: null}), isNull);
    });
  });

  test('reads an action named by the native side, and nothing it does not know', () {
    expect(HotkeyAction.named('frame'), HotkeyAction.frame);
    expect(HotkeyAction.named('zoom'), isNull);
    expect(HotkeyAction.named(null), isNull);
  });
}
