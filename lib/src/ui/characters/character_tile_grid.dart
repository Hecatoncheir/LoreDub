// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The cards in as many equal columns as fit, in the grid the model tiles
/// use — wider, because a card carries a name to type in as well as its
/// buttons.
class CharacterTileGrid extends StatelessWidget {
  const CharacterTileGrid({super.key, required this.children, this.height = 182});

  static const _minWidth = 248.0;
  static const _gap = 14.0;

  final List<Widget> children;
  final double height;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = math.max(1, ((constraints.maxWidth + _gap) / (_minWidth + _gap)).floor());
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
