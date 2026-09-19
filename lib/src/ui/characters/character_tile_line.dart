// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../theme.dart';

/// One line of a character tile, in the small monospaced type they all
/// share, giving way to the others when the card is short.
class CharacterTileLine extends StatelessWidget {
  const CharacterTileLine({
    super.key,
    required this.text,
    this.top = 0,
    this.color = LoreDubPalette.mutedInk,
    this.bold = false,
    this.maxLines = 1,
  });

  final String text;
  final double top;
  final Color color;
  final bool bold;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Flexible(
    child: Padding(
      padding: EdgeInsets.only(top: top),
      child: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: LoreDubFonts.mono,
          fontSize: 11,
          color: color,
          fontWeight: bold ? FontWeight.w600 : null,
        ),
      ),
    ),
  );
}
