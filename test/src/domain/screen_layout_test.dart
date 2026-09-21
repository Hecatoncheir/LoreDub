// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/ocr_region.dart';
import 'package:lore_dub/src/domain/screen_layout.dart';

void main() {
  test('reads the monitors as the native side lists them', () {
    final layout = ScreenLayout.fromJson(const [
      {'left': 0, 'top': 0, 'right': 2560, 'bottom': 1440, 'primary': true},
      {'left': -1920, 'top': 360, 'right': 0, 'bottom': 1440},
    ]);

    expect(layout.monitors.first.area.width, 2560);
    expect(layout.monitors.first.primary, isTrue);
    expect(layout.monitors.last.area.left, -1920);
    expect(layout.monitors.last.primary, isFalse);
  });

  test('two monitors side by side make a picture twice as wide', () {
    // The frame over the whole screen is a share of both together: the
    // picture drawn on one monitor's shape is what put it in the wrong place.
    final layout = ScreenLayout.fromJson(const [
      {'left': 0, 'top': 0, 'right': 1920, 'bottom': 1080, 'primary': true},
      {'left': 1920, 'top': 0, 'right': 3840, 'bottom': 1080},
    ]);

    expect(layout.aspectRatio, closeTo(32 / 9, 1e-9));
    expect(layout.shares, [
      (const OcrRegion(left: 0, top: 0, right: 0.5, bottom: 1), true),
      (const OcrRegion(left: 0.5, top: 0, right: 1, bottom: 1), false),
    ]);
  });

  test('a monitor to the left of the primary one is measured from the far edge', () {
    // Windows puts the primary monitor at the origin, so one standing to its
    // left has negative coordinates; the virtual screen starts there.
    final layout = ScreenLayout.fromJson(const [
      {'left': 0, 'top': 0, 'right': 2560, 'bottom': 1440, 'primary': true},
      {'left': -1920, 'top': 360, 'right': 0, 'bottom': 1440},
    ]);

    expect(layout.bounds?.left, -1920);
    expect(layout.aspectRatio, closeTo(4480 / 1440, 1e-9));
    final (primary, _) = layout.shares.first;
    final (side, _) = layout.shares.last;
    expect(primary.left, closeTo(1920 / 4480, 1e-9));
    expect(side.left, 0);
    expect(side.top, closeTo(0.25, 1e-9), reason: 'the smaller monitor sits lower');
  });

  test('no monitor of any size leaves the shape to the window', () {
    expect(const ScreenLayout([]).aspectRatio, isNull);
    expect(const ScreenLayout([]).shares, isEmpty);
    expect(
      ScreenLayout.fromJson(const [
        {'left': 0, 'top': 0, 'right': 0, 'bottom': 0},
      ]).bounds,
      isNull,
    );
  });
}
