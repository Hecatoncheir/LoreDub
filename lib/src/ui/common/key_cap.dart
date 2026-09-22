// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../theme.dart';

/// One key the player is told to press, drawn as a key: framed in the edge
/// a control the player can press wears, standing a pixel off the line on
/// its own lower edge, lettered as an instrument is.
class KeyCap extends StatelessWidget {
  const KeyCap(this.label, {super.key, this.fontSize = 13});

  /// How the key reads on the keyboard: "Ctrl", "F9", "Esc".
  final String label;

  /// How large the text around it is set, which the key is lettered a
  /// little under, so that it sits in a line of it without widening it.
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.4),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        border: Border.all(color: colors.strongOutline),
        boxShadow: [BoxShadow(color: colors.strongOutline, offset: const Offset(0, 1))],
      ),
      child: Text(
        label,
        style: context.textStyles.monoCaption.copyWith(
          color: colors.ink,
          fontSize: fontSize * 0.85,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    );
  }
}
