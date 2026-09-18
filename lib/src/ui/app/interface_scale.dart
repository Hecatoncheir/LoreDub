// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

/// Draws [child] larger or smaller than the window it is given.
///
/// The child is laid out in a window of its own -- the real one divided by
/// the scale -- and the drawing is stretched back over the real one, so a
/// scaled interface reflows rather than being a picture of a smaller one.
/// `Transform` carries the pointer back through the same matrix, so what is
/// clicked is what was drawn.
class InterfaceScale extends StatelessWidget {
  const InterfaceScale({super.key, required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (scale == 1) return child;
    final media = MediaQuery.of(context);
    final size = media.size / scale;
    return MediaQuery(
      data: media.copyWith(size: size, devicePixelRatio: media.devicePixelRatio * scale),
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topLeft,
        // The home of a MaterialApp is given the window's size as a tight
        // constraint, and a SizedBox cannot shrink under one: the child was
        // laid out at the window's own size and then magnified past its
        // edge. OverflowBox lets it take the size it is asked for, which is
        // the window divided by the scale, so magnifying it lands back
        // exactly on the window.
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          maxWidth: double.infinity,
          minHeight: 0,
          maxHeight: double.infinity,
          child: SizedBox(width: size.width, height: size.height, child: child),
        ),
      ),
    );
  }
}
