// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

/// The two language pickers sit in different rows, so they are laid out
/// identically — same field width, same gap, same trailing width — to line up
/// exactly one under the other.
class LanguageRow extends StatelessWidget {
  const LanguageRow({super.key, required this.field, required this.action});

  static const double fieldWidth = 210;

  /// Wide enough for the detected language to replace the toggle's label
  /// without being cut short.
  static const double actionWidth = 240;

  /// What the two of them need side by side.
  static const double _sideBySide = fieldWidth + 12 + actionWidth;

  final Widget field;
  final Widget action;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    // Both halves were fixed and the row refused to shrink, so a card
    // narrower than the two of them -- the screen page's controls beside
    // the subtitle frame -- was overflowed by whatever was missing. Given
    // less than they need, they go one under the other and take the width
    // there is.
    builder: (context, constraints) =>
        !constraints.hasBoundedWidth || constraints.maxWidth >= _sideBySide
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: fieldWidth, child: field),
              const SizedBox(width: 12),
              SizedBox(width: actionWidth, child: action),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [field, const SizedBox(height: 10), action],
          ),
  );
}
