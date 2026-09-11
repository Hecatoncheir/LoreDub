// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math' as math;

/// Where on the game window the subtitles are read.
///
/// Every edge is a fraction of the window's client area, from its top-left
/// corner, so one frame fits whatever resolution the game runs at.
class OcrRegion {
  const OcrRegion({this.left = 0, this.top = 0.55, this.right = 1, this.bottom = 1});

  /// The lower band of the whole window, which is where most games print
  /// their lines and what builds before the frame could be drawn scanned.
  static const standard = OcrRegion();

  /// The smallest frame, as a share of each side. Anything narrower cannot
  /// hold a line of text Windows OCR would find.
  static const minimumWidth = 0.05;
  static const minimumHeight = 0.04;

  /// The frame spanned by two corners given in either order.
  factory OcrRegion.fromCorners(double x1, double y1, double x2, double y2) => OcrRegion(
    left: math.min(x1, x2),
    top: math.min(y1, y2),
    right: math.max(x1, x2),
    bottom: math.max(y1, y2),
  ).normalized();

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  /// The same frame kept on the window and no smaller than the minimum, so a
  /// value stored by hand or by an older build still captures something.
  OcrRegion normalized() {
    final (newLeft, newRight) = _span(left, right, minimumWidth);
    final (newTop, newBottom) = _span(top, bottom, minimumHeight);
    return OcrRegion(left: newLeft, top: newTop, right: newRight, bottom: newBottom);
  }

  /// The frame shifted as a whole, stopping at the window's edges without
  /// changing size.
  OcrRegion translated(double dx, double dy) {
    final x = dx.clamp(-left, 1 - right);
    final y = dy.clamp(-top, 1 - bottom);
    return OcrRegion(left: left + x, top: top + y, right: right + x, bottom: bottom + y);
  }

  /// The frame with the named edges moved, each stopping at the window and
  /// short of the minimum size against the edge opposite it.
  OcrRegion withEdges({double? left, double? top, double? right, double? bottom}) {
    var newLeft = this.left;
    var newTop = this.top;
    var newRight = this.right;
    var newBottom = this.bottom;
    if (left != null) newLeft = math.min(left.clamp(0.0, 1.0), newRight - minimumWidth);
    if (right != null) newRight = math.max(right.clamp(0.0, 1.0), newLeft + minimumWidth);
    if (top != null) newTop = math.min(top.clamp(0.0, 1.0), newBottom - minimumHeight);
    if (bottom != null) newBottom = math.max(bottom.clamp(0.0, 1.0), newTop + minimumHeight);
    return OcrRegion(left: newLeft, top: newTop, right: newRight, bottom: newBottom).normalized();
  }

  static (double, double) _span(double start, double end, double minimum) {
    var low = math.min(start, end).clamp(0.0, 1.0);
    var high = math.max(start, end).clamp(0.0, 1.0);
    if (high - low < minimum) {
      high = math.min(1.0, low + minimum);
      low = high - minimum;
    }
    return (low, high);
  }

  @override
  bool operator ==(Object other) =>
      other is OcrRegion &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'OcrRegion($left, $top, $right, $bottom)';
}
