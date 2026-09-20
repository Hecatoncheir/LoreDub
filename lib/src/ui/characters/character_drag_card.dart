// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../theme.dart';

/// What the pointer carries while a card is being dragged: its name alone,
/// small enough to see where it is going.
class CharacterDragCard extends StatelessWidget {
  const CharacterDragCard({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: const Offset(-70, -22),
    child: Material(
      color: context.colors.deep,
      elevation: 8,
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.drag_indicator_rounded, size: 18, color: context.colors.accent),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                fontFamily: LoreDubFonts.display,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.colors.raised,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
