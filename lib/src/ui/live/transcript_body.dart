// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

/// How much of a transcript card the lines take.
///
/// They fill the card where the card fills the window, and come to their
/// own height where the page scrolls instead. A card holding nothing keeps
/// a height all the same: what it says about where the lines will come from
/// is worth room to be read in.
class TranscriptBody extends StatelessWidget {
  const TranscriptBody({
    super.key,
    required this.lines,
    required this.fillsHeight,
    required this.empty,
  });

  final Widget lines;
  final bool fillsHeight;
  final bool empty;

  static const _emptyHeight = 180.0;

  @override
  Widget build(BuildContext context) {
    if (fillsHeight) return Expanded(child: lines);
    return empty ? SizedBox(height: _emptyHeight, child: lines) : lines;
  }
}
