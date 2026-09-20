// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

/// How much of a transcript card the lines take.
///
/// They fill the card where the card fills the window. Where the page
/// scrolls instead, the card grows with them until ten lines are in it and
/// then holds that height, the older ones scrolling away inside: a page
/// that grew without end would leave the areas beside it out of reach. A
/// card holding nothing keeps a height all the same -- what it says about
/// where the lines will come from is worth room to be read in.
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

  /// What ten lines come to: a line of the game with its translation under
  /// it, and the space between two of them. Lines are not all of a height
  /// -- a long one wraps -- so this is what ten of them usually take
  /// rather than a promise.
  static const linesInView = 10;
  static const _lineHeight = 88.0;
  static const _listPadding = 44.0;
  static const grownHeight = linesInView * _lineHeight + _listPadding;

  @override
  Widget build(BuildContext context) {
    if (fillsHeight) return Expanded(child: lines);
    if (empty) return SizedBox(height: _emptyHeight, child: lines);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: grownHeight),
      child: lines,
    );
  }
}
