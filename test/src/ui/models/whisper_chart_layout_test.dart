// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/ui/models/whisper_chart_layout.dart';

void main() {
  const mb = 1024 * 1024;

  test('stands every bar on the axis, as tall as its download to scale', () {
    final layout = WhisperChartLayout.of([150 * mb, 500 * mb, 1500 * mb], 1200);

    for (final bar in layout.bars) {
      expect(bar.bottom, closeTo(WhisperChartLayout.baseline, 0.001));
    }
    expect(layout.bars[2].height, greaterThan(layout.bars[1].height));
    expect(layout.bars[2].height, lessThan(WhisperChartLayout.plotHeight));
  });

  test('keeps a small download tall enough to hold its name and buttons', () {
    final layout = WhisperChartLayout.of([30 * mb, 3000 * mb], 1200);

    expect(layout.bars.first.height, WhisperChartLayout.minBarHeight);
  });

  test('pushes labels that would overlap apart, the lowest staying put', () {
    final layout = WhisperChartLayout.of([1500 * mb, 1540 * mb, 1560 * mb], 1200);
    final centres = [...layout.labelCentres]..sort();

    expect(layout.labelCentres.first, layout.bars.first.top);
    for (var index = 1; index < centres.length; index++) {
      expect(centres[index] - centres[index - 1], greaterThanOrEqualTo(17 - 0.001));
    }
  });
}
