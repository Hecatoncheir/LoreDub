// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../theme.dart';

/// One half of a screen that has two -- Эфир, Экран -- as the title of the
/// screen: the one that is up is the title, in the colour of what is
/// chosen, and the other stands beside it smaller and quieter -- a word to
/// press rather than a second heading.
class TitleWord extends StatelessWidget {
  const TitleWord({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
    this.compact = false,
  });

  final String label;

  /// The mark this half is known by: the one its screen carries in the
  /// navigation, and the tree of the scheme.
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  /// Whether the header is too narrow for both words, so the half that is
  /// not up stands as its mark alone, named by its tooltip.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final titles = Theme.of(context).textTheme;
    final style = selected
        ? titles.headlineSmall?.copyWith(color: context.colors.accent)
        : titles.titleLarge?.copyWith(color: context.colors.mutedInk);
    final buttonStyle = TextButton.styleFrom(
      // A title is read, not aimed at: it keeps the room the words take
      // rather than the room a button would ask for.
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      foregroundColor: context.colors.mutedInk,
      disabledForegroundColor: context.colors.accent,
      textStyle: style,
    );
    if (compact && !selected) {
      return Tooltip(
        message: label,
        child: TextButton(
          onPressed: onPressed,
          style: buttonStyle,
          child: Icon(icon, size: 18),
        ),
      );
    }
    return TextButton.icon(
      onPressed: selected ? null : onPressed,
      icon: Icon(icon, size: selected ? 22 : 18),
      style: buttonStyle,
      label: Text(label, style: style),
    );
  }
}
