// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../theme.dart';

/// One half of Эфир, as the title of the screen: the one that is up is the
/// title, in the colour of what is chosen, and the other stands beside it
/// smaller and quieter -- a word to press rather than a second heading.
class LiveTitleWord extends StatelessWidget {
  const LiveTitleWord({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;

  /// The mark this half is known by, the same one its screen carried when
  /// it was one: the wave of a voice, the tree of the scheme.
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final titles = Theme.of(context).textTheme;
    final style = selected
        ? titles.headlineSmall?.copyWith(color: context.colors.accent)
        : titles.titleLarge?.copyWith(color: context.colors.mutedInk);
    return TextButton.icon(
      onPressed: selected ? null : onPressed,
      icon: Icon(icon, size: selected ? 22 : 18),
      style: TextButton.styleFrom(
        // A title is read, not aimed at: it keeps the room the words take
        // rather than the room a button would ask for.
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: context.colors.mutedInk,
        disabledForegroundColor: context.colors.accent,
        textStyle: style,
      ),
      label: Text(label, style: style),
    );
  }
}
