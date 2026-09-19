// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math' as math;
import 'dart:ui';

/// The shape of a line between two sockets: a curve that leaves each socket
/// level before it bends, so two nodes side by side are joined by a bow
/// rather than a corner.
abstract final class LinkGeometry {
  /// How far the curve leaves a socket before it bends.
  static double _reach(Offset from, Offset to) => math.max(60, (to.dx - from.dx).abs() * 0.5);

  static Path pathBetween(Offset from, Offset to) {
    final reach = _reach(from, to);
    return Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(from.dx + reach, from.dy, to.dx - reach, to.dy, to.dx, to.dy);
  }

  /// The middle of the curve, where its badge sits.
  static Offset middleOf(Offset from, Offset to) {
    final reach = _reach(from, to);
    final c1 = Offset(from.dx + reach, from.dy);
    final c2 = Offset(to.dx - reach, to.dy);
    // The cubic at t = 0.5, which is the eighth-sum of the four points.
    return (from + c1 * 3 + c2 * 3 + to) / 8;
  }

  /// The first [share] of [path], measured along the curve.
  static Path upTo(Path path, double share) {
    if (share >= 1) return path;
    final drawn = Path();
    for (final metric in path.computeMetrics()) {
      drawn.addPath(metric.extractPath(0, metric.length * share.clamp(0.0, 1.0)), Offset.zero);
    }
    return drawn;
  }

  /// [path] as a dashed copy of itself. Flutter strokes whole paths only, so
  /// the dashes are cut out of the metrics by hand.
  static Path dashed(Path path, {double on = 9, double off = 7}) {
    final dashes = Path();
    for (final metric in path.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += on + off) {
        dashes.addPath(
          metric.extractPath(distance, math.min(distance + on, metric.length)),
          Offset.zero,
        );
      }
    }
    return dashes;
  }
}
