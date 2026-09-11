// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/services.dart';

/// The Windows virtual-key code for a key the player pressed, or null for a
/// key a hotkey cannot use.
int? windowsKeyCode(LogicalKeyboardKey key) {
  final special = _keyCodes[key];
  if (special != null) return special;
  final label = key.keyLabel;
  if (label.length != 1) return null;
  final unit = label.toUpperCase().codeUnitAt(0);
  // Letters and digits: their virtual-key codes are the characters' own.
  final letter = unit >= 0x41 && unit <= 0x5A;
  final digit = unit >= 0x30 && unit <= 0x39;
  return letter || digit ? unit : null;
}

/// How the key reads in a combination: "K", "F9", "Space".
String hotkeyLabel(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.space) return 'Space';
  final label = key.keyLabel;
  return label.length == 1 ? label.toUpperCase() : label;
}

/// Keys that only modify another, and are read from the keyboard's state
/// rather than bound themselves.
bool isModifierKey(LogicalKeyboardKey key) => _modifiers.contains(key);

final _modifiers = {
  LogicalKeyboardKey.control,
  LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey.controlRight,
  LogicalKeyboardKey.alt,
  LogicalKeyboardKey.altLeft,
  LogicalKeyboardKey.altRight,
  LogicalKeyboardKey.shift,
  LogicalKeyboardKey.shiftLeft,
  LogicalKeyboardKey.shiftRight,
  LogicalKeyboardKey.meta,
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.metaRight,
};

const _functionKeys = [
  LogicalKeyboardKey.f1,
  LogicalKeyboardKey.f2,
  LogicalKeyboardKey.f3,
  LogicalKeyboardKey.f4,
  LogicalKeyboardKey.f5,
  LogicalKeyboardKey.f6,
  LogicalKeyboardKey.f7,
  LogicalKeyboardKey.f8,
  LogicalKeyboardKey.f9,
  LogicalKeyboardKey.f10,
  LogicalKeyboardKey.f11,
  LogicalKeyboardKey.f12,
  LogicalKeyboardKey.f13,
  LogicalKeyboardKey.f14,
  LogicalKeyboardKey.f15,
  LogicalKeyboardKey.f16,
  LogicalKeyboardKey.f17,
  LogicalKeyboardKey.f18,
  LogicalKeyboardKey.f19,
  LogicalKeyboardKey.f20,
  LogicalKeyboardKey.f21,
  LogicalKeyboardKey.f22,
  LogicalKeyboardKey.f23,
  LogicalKeyboardKey.f24,
];

const _numpadDigits = [
  LogicalKeyboardKey.numpad0,
  LogicalKeyboardKey.numpad1,
  LogicalKeyboardKey.numpad2,
  LogicalKeyboardKey.numpad3,
  LogicalKeyboardKey.numpad4,
  LogicalKeyboardKey.numpad5,
  LogicalKeyboardKey.numpad6,
  LogicalKeyboardKey.numpad7,
  LogicalKeyboardKey.numpad8,
  LogicalKeyboardKey.numpad9,
];

/// Everything that is neither a letter nor a digit, by its VK_* code.
final _keyCodes = <LogicalKeyboardKey, int>{
  for (var index = 0; index < _functionKeys.length; index++) _functionKeys[index]: 0x70 + index,
  for (var index = 0; index < _numpadDigits.length; index++) _numpadDigits[index]: 0x60 + index,
  LogicalKeyboardKey.numpadMultiply: 0x6A,
  LogicalKeyboardKey.numpadAdd: 0x6B,
  LogicalKeyboardKey.numpadSubtract: 0x6D,
  LogicalKeyboardKey.numpadDecimal: 0x6E,
  LogicalKeyboardKey.numpadDivide: 0x6F,
  LogicalKeyboardKey.pause: 0x13,
  LogicalKeyboardKey.scrollLock: 0x91,
  LogicalKeyboardKey.space: 0x20,
  LogicalKeyboardKey.pageUp: 0x21,
  LogicalKeyboardKey.pageDown: 0x22,
  LogicalKeyboardKey.end: 0x23,
  LogicalKeyboardKey.home: 0x24,
  LogicalKeyboardKey.arrowLeft: 0x25,
  LogicalKeyboardKey.arrowUp: 0x26,
  LogicalKeyboardKey.arrowRight: 0x27,
  LogicalKeyboardKey.arrowDown: 0x28,
  LogicalKeyboardKey.insert: 0x2D,
  LogicalKeyboardKey.delete: 0x2E,
  LogicalKeyboardKey.semicolon: 0xBA,
  LogicalKeyboardKey.equal: 0xBB,
  LogicalKeyboardKey.comma: 0xBC,
  LogicalKeyboardKey.minus: 0xBD,
  LogicalKeyboardKey.period: 0xBE,
  LogicalKeyboardKey.slash: 0xBF,
  LogicalKeyboardKey.backquote: 0xC0,
  LogicalKeyboardKey.bracketLeft: 0xDB,
  LogicalKeyboardKey.backslash: 0xDC,
  LogicalKeyboardKey.bracketRight: 0xDD,
  LogicalKeyboardKey.quote: 0xDE,
};
