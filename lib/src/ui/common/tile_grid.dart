// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tiles in as many equal columns as fit, left-aligned so a lone tile keeps
/// the size of its neighbours in the section above. The models, the GPU
/// runtimes and the cast are laid out by it; a card of the cast asks for a
/// wider column, carrying a name to type in as well as its buttons.
class TileGrid extends StatelessWidget {
  const TileGrid({
    super.key,
    required this.children,
    this.minWidth = modelWidth,
    this.height = modelHeight,
  });

  static const modelWidth = 200.0;
  static const modelHeight = 196.0;
  static const characterWidth = 248.0;
  static const characterHeight = 182.0;
  static const _gap = 14.0;

  final List<Widget> children;
  final double minWidth;
  final double height;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = math.max(1, ((constraints.maxWidth + _gap) / (minWidth + _gap)).floor());
      final width = ((constraints.maxWidth - _gap * (columns - 1)) / columns).floorToDouble();
      return Wrap(
        spacing: _gap,
        runSpacing: _gap,
        children: [
          for (final child in children) SizedBox(width: width, height: height, child: child),
        ],
      );
    },
  );
}
