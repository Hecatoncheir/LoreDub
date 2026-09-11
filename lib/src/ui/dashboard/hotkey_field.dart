// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/hotkey.dart';
import '../hotkey_keys.dart';
import '../theme.dart';

/// A combination for one action, recorded by pressing it.
///
/// A click puts the field into listening; the next key pressed together with
/// whatever modifiers are held becomes the combination, Esc gives up, and a
/// combination that cannot be taken says why without being saved.
class HotkeyField extends StatefulWidget {
  const HotkeyField({
    super.key,
    required this.value,
    required this.enabled,
    required this.validate,
    required this.onChanged,
  });

  final Hotkey? value;
  final bool enabled;

  /// Why [Hotkey] cannot be taken, or null when it can.
  final String? Function(Hotkey hotkey) validate;

  /// Called with the new combination, or null once it was removed.
  final ValueChanged<Hotkey?> onChanged;

  @override
  State<HotkeyField> createState() => _HotkeyFieldState();
}

class _HotkeyFieldState extends State<HotkeyField> {
  final _focus = FocusNode(debugLabel: 'hotkey');
  var _listening = false;
  String? _problem;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _listen() {
    setState(() {
      _listening = true;
      _problem = null;
    });
    _focus.requestFocus();
  }

  void _stopListening() {
    if (_listening) setState(() => _listening = false);
    _focus.unfocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_listening) return KeyEventResult.ignored;
    // Every key is swallowed while listening, so Space or Enter cannot
    // press the field itself instead of being recorded.
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _stopListening();
      return KeyEventResult.handled;
    }
    if (isModifierKey(key)) return KeyEventResult.handled;
    final l10n = AppLocalizations.of(context);
    final keyCode = windowsKeyCode(key);
    if (keyCode == null) {
      setState(() => _problem = l10n.hotkeyUnsupported);
      return KeyEventResult.handled;
    }
    final keyboard = HardwareKeyboard.instance;
    final hotkey = Hotkey(
      keyCode: keyCode,
      label: hotkeyLabel(key),
      control: keyboard.isControlPressed,
      alt: keyboard.isAltPressed,
      shift: keyboard.isShiftPressed,
      win: keyboard.isMetaPressed,
    );
    final problem = widget.validate(hotkey);
    setState(() => _problem = problem);
    if (problem == null) {
      _stopListening();
      widget.onChanged(hotkey);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = widget.value;
    final text = _listening ? l10n.hotkeyListening : value?.display ?? l10n.hotkeyUnset;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Focus(
                focusNode: _focus,
                onKeyEvent: _onKey,
                onFocusChange: (focused) {
                  if (!focused && _listening) setState(() => _listening = false);
                },
                child: OutlinedButton(
                  onPressed: widget.enabled ? _listen : null,
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    side: BorderSide(
                      color: _listening ? LoreDubPalette.orange : LoreDubPalette.graphite,
                      width: _listening ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontFamily: LoreDubFonts.mono,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _listening
                          ? LoreDubPalette.orangeDark
                          : value == null
                          ? LoreDubPalette.mutedInk
                          : LoreDubPalette.ink,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: l10n.hotkeyClear,
              onPressed: widget.enabled && value != null
                  ? () {
                      setState(() => _problem = null);
                      widget.onChanged(null);
                    }
                  : null,
              icon: const Icon(Icons.backspace_outlined, size: 20),
            ),
          ],
        ),
        if (_problem case final problem?)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              problem,
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
