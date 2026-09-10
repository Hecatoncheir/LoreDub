// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/progress_ticker.dart';

void main() {
  test('reports only what the reader can see change', () {
    final ticker = ProgressTicker();

    expect(ticker.shouldReport(0.010), isTrue);
    expect(ticker.shouldReport(0.011), isFalse, reason: 'still 1%');
    expect(ticker.shouldReport(0.019), isFalse);
    expect(ticker.shouldReport(0.020), isTrue, reason: '2% is a new number');
  });

  test('always reports the end, even without a step', () {
    final ticker = ProgressTicker();
    ticker.shouldReport(1);

    expect(ticker.shouldReport(1), isTrue, reason: 'the bar has to close');
  });

  test('cuts a chunked download to about one report per percent', () {
    final ticker = ProgressTicker();
    // A 300 MB file in 64 KB chunks is roughly this many callbacks.
    const chunks = 4800;
    var reported = 0;
    for (var chunk = 1; chunk <= chunks; chunk++) {
      if (ticker.shouldReport(chunk / chunks)) reported++;
    }

    expect(reported, lessThanOrEqualTo(101));
    expect(reported, greaterThan(90), reason: 'every percent still arrives');
  });

  test('survives values outside the range', () {
    final ticker = ProgressTicker();

    expect(ticker.shouldReport(-1), isTrue);
    expect(ticker.shouldReport(5), isTrue);
  });
}
