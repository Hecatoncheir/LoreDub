// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math' as math;

import 'ocr_region.dart';

/// One monitor, in the virtual screen's physical pixels.
class Monitor {
  const Monitor(this.area, {this.primary = false});

  factory Monitor.fromJson(Map<String, Object?> json) {
    int edge(String key) => (json[key] as num?)?.toInt() ?? 0;
    final left = edge('left');
    final top = edge('top');
    return Monitor(
      math.Rectangle(left, top, edge('right') - left, edge('bottom') - top),
      primary: json['primary'] == true,
    );
  }

  final math.Rectangle<int> area;

  /// The one the taskbar and the dialogue hints are drawn on.
  final bool primary;

  @override
  bool operator ==(Object other) =>
      other is Monitor && other.area == area && other.primary == primary;

  @override
  int get hashCode => Object.hash(area, primary);
}

/// Where the monitors stand against each other.
///
/// A frame read "over the whole screen" is a share of the rectangle every
/// monitor spans together, which is not the shape of any one of them: two
/// monitors side by side make a band twice as wide, and a frame over the
/// lower half of that band crosses both. A picture of the frame drawn on
/// the shape of the monitor LoreDub happened to stand on put it somewhere
/// it was not read from.
class MonitorLayout {
  const MonitorLayout(this.monitors);

  factory MonitorLayout.fromJson(List<Object?> json) => MonitorLayout([
    for (final value in json) Monitor.fromJson(value! as Map<String, Object?>),
  ]);

  final List<Monitor> monitors;

  /// What they cover together: the virtual screen. Null with no monitor of
  /// any size, which leaves the picture to the shape of the window's own.
  math.Rectangle<int>? get bounds {
    final shown = _shown;
    if (shown.isEmpty) return null;
    return shown.map((monitor) => monitor.area).reduce((a, b) => a.boundingBox(b));
  }

  Iterable<Monitor> get _shown =>
      monitors.where((monitor) => monitor.area.width > 0 && monitor.area.height > 0);

  /// Width over height of [bounds], or null where there is none.
  double? get aspectRatio {
    final all = bounds;
    return all == null ? null : all.width / all.height;
  }

  /// Every monitor as a share of [bounds], the way a frame is stored, so
  /// the two can be drawn on the same picture.
  List<(OcrRegion, bool)> get shares {
    final all = bounds;
    if (all == null) return const [];
    double across(int x) => (x - all.left) / all.width;
    double down(int y) => (y - all.top) / all.height;
    return [
      for (final monitor in _shown)
        (
          OcrRegion(
            left: across(monitor.area.left),
            top: down(monitor.area.top),
            right: across(monitor.area.right),
            bottom: down(monitor.area.bottom),
          ),
          monitor.primary,
        ),
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is MonitorLayout &&
      other.monitors.length == monitors.length &&
      Iterable<int>.generate(monitors.length).every((i) => other.monitors[i] == monitors[i]);

  @override
  int get hashCode => Object.hashAll(monitors);
}
