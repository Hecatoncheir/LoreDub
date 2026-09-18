// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tiles in as many equal columns as fit, left-aligned so a lone tile keeps
/// the size of its neighbours in the section above.
class ModelTileGrid extends StatelessWidget {
  const ModelTileGrid({super.key, required this.children});

  static const _minWidth = 200.0;
  static const _gap = 14.0;
  static const _height = 196.0;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = math.max(1, ((constraints.maxWidth + _gap) / (_minWidth + _gap)).floor());
      final width = ((constraints.maxWidth - _gap * (columns - 1)) / columns).floorToDouble();
      return Wrap(
        spacing: _gap,
        runSpacing: _gap,
        children: [
          for (final child in children) SizedBox(width: width, height: _height, child: child),
        ],
      );
    },
  );
}
