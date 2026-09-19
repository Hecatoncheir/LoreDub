// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/ui/common/ease.dart';

void main() {
  Future<Duration> easeUnder(WidgetTester tester, {required bool still}) async {
    late Duration taken;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: Builder(
          builder: (context) {
            taken = ease(context, 150);
            return const SizedBox();
          },
        ),
      ),
    );
    return taken;
  }

  testWidgets('takes the time asked for, and none with animation turned off', (tester) async {
    expect(await easeUnder(tester, still: false), const Duration(milliseconds: 150));
    expect(await easeUnder(tester, still: true), Duration.zero);
  });
}
