// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/ui/common/focus_region.dart';

void main() {
  testWidgets('the keyboard reaches it, and the space bar acts on it', (tester) async {
    var activated = 0;
    final focused = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FocusRegion(
            onActivate: () => activated++,
            builder: (context, has) {
              focused.add(has);
              return const SizedBox(width: 80, height: 40);
            },
          ),
        ),
      ),
    );

    expect(focused.last, isFalse, reason: 'nothing is focused to begin with');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(focused.last, isTrue, reason: 'one tab reaches it');

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(activated, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(activated, 2, reason: 'enter acts on it as well');
  });
}
