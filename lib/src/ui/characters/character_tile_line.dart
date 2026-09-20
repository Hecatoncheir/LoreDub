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
    this.color,
    this.bold = false,
    this.maxLines = 1,
  });

  final String text;
  final double top;

  /// What the line is said in. The quiet ink where nothing else is asked
  /// for.
  final Color? color;
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
        style: context.textStyles.monoCaption.copyWith(
          color: color ?? context.colors.mutedInk,
          fontWeight: bold ? FontWeight.w600 : null,
        ),
      ),
    ),
  );
}
