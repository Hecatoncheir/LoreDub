// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/speech_pace.dart';

void main() {
  test('reads at the pace the player chose while the queue is short', () {
    expect(hurriedSpeed(1.12, 0), 1.12);
    expect(hurriedSpeed(1.12, patientLines), 1.12, reason: 'a scene answers itself');
  });

  test('hurries by a tenth for every line queued past that', () {
    expect(hurriedSpeed(1.0, 3), closeTo(1.1, 1e-9));
    expect(hurriedSpeed(1.0, 5), closeTo(1.3, 1e-9));
    expect(hurriedSpeed(1.12, 4), closeTo(1.12 * 1.2, 1e-9));
  });

  test('never reads faster than it can be followed', () {
    expect(hurriedSpeed(1.0, 40), closeTo(hurryLimit, 1e-9));
    // The worker retimes at most twice, so neither does this.
    expect(hurriedSpeed(1.6, 40), 2.0);
  });
}
