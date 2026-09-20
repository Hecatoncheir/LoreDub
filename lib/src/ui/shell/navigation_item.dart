// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../theme.dart';

/// One section in the sidebar, marked while it is the one on screen.
class NavigationItem extends StatelessWidget {
  const NavigationItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// Built rather than passed ready-made: the colour depends on [selected],
  /// and not every mark here comes from the icon font.
  final Widget Function(Color color) icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Material(
        color: selected ? context.colors.deep : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                const SizedBox(width: 12),
                icon(selected ? context.colors.accent : context.colors.ink),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : context.colors.ink,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
