// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// A key combination bound to an action, in the terms Windows registers it.
class Hotkey {
  const Hotkey({
    required this.keyCode,
    required this.label,
    this.control = false,
    this.alt = false,
    this.shift = false,
    this.win = false,
  });

  /// What a fresh installation offers: letters named for the action, behind
  /// two modifiers no game reserves for anything much.
  static const defaultPause = Hotkey(keyCode: 0x50, label: 'P', control: true, alt: true);
  static const defaultResume = Hotkey(keyCode: 0x52, label: 'R', control: true, alt: true);

  /// Held rather than pressed: the area is drawn while it is down.
  static const defaultSnapshot = Hotkey(keyCode: 0x53, label: 'S', control: true, alt: true);

  /// The Windows virtual-key code of the main key.
  final int keyCode;

  /// How the main key reads on the keyboard: "P", "F9", "Page Up".
  final String label;
  final bool control;
  final bool alt;
  final bool shift;
  final bool win;

  /// RegisterHotKey's MOD_ALT, MOD_CONTROL, MOD_SHIFT and MOD_WIN.
  int get modifiers => (alt ? 0x1 : 0) | (control ? 0x2 : 0) | (shift ? 0x4 : 0) | (win ? 0x8 : 0);

  /// "Ctrl + Alt + P", in the order Windows itself writes combinations.
  String get display => [
    if (control) 'Ctrl',
    if (alt) 'Alt',
    if (shift) 'Shift',
    if (win) 'Win',
    label,
  ].join(' + ');

  /// Whether binding it leaves the game its keys. Windows hands a registered
  /// combination to LoreDub alone, so a bare letter — or Shift with one —
  /// would stop reaching the game and every chat in it. Function keys, Pause
  /// and Scroll Lock can stand alone; anything else needs Ctrl, Alt or Win.
  bool get leavesGameKeys => standsAlone(keyCode) || control || alt || win;

  bool sameCombination(Hotkey other) => keyCode == other.keyCode && modifiers == other.modifiers;

  /// Stored as "code:modifiers:label".
  String encode() => '$keyCode:$modifiers:$label';

  /// Reads what [encode] wrote, or null for anything else.
  static Hotkey? decode(String value) {
    final parts = value.split(':');
    if (parts.length < 3) return null;
    final keyCode = int.tryParse(parts[0]);
    final modifiers = int.tryParse(parts[1]);
    final label = parts.sublist(2).join(':');
    if (keyCode == null || keyCode <= 0 || modifiers == null || label.isEmpty) return null;
    return Hotkey(
      keyCode: keyCode,
      label: label,
      alt: modifiers & 0x1 != 0,
      control: modifiers & 0x2 != 0,
      shift: modifiers & 0x4 != 0,
      win: modifiers & 0x8 != 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Hotkey && sameCombination(other) && other.label == label;

  @override
  int get hashCode => Object.hash(keyCode, modifiers, label);
}

/// F1 to F24, Pause and Scroll Lock: keys games leave alone, so they can be
/// bound without a modifier.
bool standsAlone(int keyCode) =>
    (keyCode >= 0x70 && keyCode <= 0x87) || keyCode == 0x13 || keyCode == 0x91;
