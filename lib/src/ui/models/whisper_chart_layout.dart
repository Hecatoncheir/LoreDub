// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math' as math;
import 'dart:ui';

/// Where everything of the Whisper chart stands in a given width: the bars,
/// the size written beside each, and the axes they hang from.
class WhisperChartLayout {
  WhisperChartLayout._({required this.width, required this.bars, required this.labelCentres});

  /// Lays out bars for packages of [sizes] bytes, in order, across [width].
  ///
  /// Each bar is as tall as its download to scale, and wider for the better
  /// models, as the reference drawing has them -- the width says nothing on
  /// its own, so it is a rank and not a measure.
  factory WhisperChartLayout.of(List<int> sizes, double width) {
    final count = sizes.length;
    final right = width - axisTitleWidth;
    final weights = [for (var index = 0; index < count; index++) 10 + 6.5 * index];
    final weightSum = weights.fold<double>(0, (sum, weight) => sum + weight);
    final room = math.max(0.0, right - labelGutter - gap * (count + 1));
    final largest = sizes.fold<int>(1, math.max);
    // A little headroom, so the largest bar does not touch the top.
    final scale = plotHeight / (largest * 1.08);
    final bars = <Rect>[];
    var x = labelGutter + gap;
    for (var index = 0; index < count; index++) {
      final barWidth = math.max(minBarWidth, room * weights[index] / weightSum);
      final height = math.max(minBarHeight, sizes[index] * scale);
      bars.add(Rect.fromLTWH(x, baseline - height, barWidth, height));
      x += barWidth + gap;
    }
    return WhisperChartLayout._(width: width, bars: bars, labelCentres: _labelCentres(bars));
  }

  /// A size is written at the height of its bar. The three larger builds
  /// weigh nearly the same, so labels that would overlap are pushed up just
  /// enough to be read, starting from the lowest.
  static List<double> _labelCentres(List<Rect> bars) {
    final centres = List<double>.filled(bars.length, 0);
    final lowestFirst = [for (var index = 0; index < bars.length; index++) index]
      ..sort((a, b) => bars[b].top.compareTo(bars[a].top));
    double? previous;
    for (final index in lowestFirst) {
      final centre = previous == null
          ? bars[index].top
          : math.min(bars[index].top, previous - labelSpacing);
      centres[index] = centre;
      previous = centre;
    }
    return centres;
  }

  /// What the sizes on the left take.
  static const labelGutter = 86.0;
  static const titleBand = 30.0;
  static const plotHeight = 400.0;
  static const qualityBand = 42.0;
  static const axisTitleWidth = 96.0;
  static const gap = 22.0;
  static const minBarWidth = 92.0;
  static const minBarHeight = 96.0;
  static const labelSpacing = 17.0;

  /// Where the bars stand on the axis.
  static const baseline = titleBand + plotHeight;

  /// The whole chart's height, the quality written under the axis included.
  static const height = baseline + qualityBand;

  final double width;
  final List<Rect> bars;
  final List<double> labelCentres;
}
