// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Something the keyboard can reach and act on, for a control drawn by hand
/// rather than built out of Material's own.
///
/// It says whether it holds the focus, the way `HoverRegion` says whether
/// the pointer is over it, so what is drawn under it can show that it is
/// next in line; Enter and the space bar call [onActivate].
///
/// A bare [Focus] rather than a `FocusableActionDetector`: that one brings a
/// mouse region of its own, and the cards of the canvas already watch the
/// pointer with theirs -- two of them over every card is hit-testing done
/// twice on every frame of a drag.
class FocusRegion extends StatefulWidget {
  const FocusRegion({super.key, required this.onActivate, required this.builder});

  final VoidCallback onActivate;
  final Widget Function(BuildContext context, bool focused) builder;

  @override
  State<FocusRegion> createState() => _FocusRegionState();
}

class _FocusRegionState extends State<FocusRegion> {
  static final _activates = {
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.space,
  };

  bool _focused = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !_activates.contains(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    widget.onActivate();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    onKeyEvent: _onKey,
    onFocusChange: (focused) => setState(() => _focused = focused),
    child: widget.builder(context, _focused),
  );
}
