// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../theme.dart';

/// What a socket carries, written beside it in the card's own port colour.
class PortLabel extends StatelessWidget {
  const PortLabel({super.key, required this.text, required this.align, required this.color});

  final String text;
  final TextAlign align;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: align,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontFamily: LoreDubFonts.mono,
      fontSize: 9,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: color,
    ),
  );
}
