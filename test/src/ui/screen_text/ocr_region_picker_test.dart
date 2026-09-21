// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/ocr_region.dart';
import 'package:lore_dub/src/domain/monitor_layout.dart';
import 'package:lore_dub/src/ui/screen_text/ocr_region_picker.dart';

void main() {
  Future<Size> pictureOf(WidgetTester tester, {MonitorLayout? monitors}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: OcrRegionPicker(
              region: OcrRegion.standard,
              onChanged: (_) {},
              semanticLabel: 'frame',
              monitors: monitors,
            ),
          ),
        ),
      ),
    );
    return tester.getSize(find.byKey(const ValueKey('ocrRegionScreen')));
  }

  testWidgets('over two monitors the picture has the shape of both', (tester) async {
    final picture = await pictureOf(
      tester,
      monitors: MonitorLayout.fromJson(const [
        {'left': 0, 'top': 0, 'right': 1920, 'bottom': 1080, 'primary': true},
        {'left': 1920, 'top': 0, 'right': 3840, 'bottom': 1080},
      ]),
    );

    expect(picture.width / picture.height, closeTo(32 / 9, 0.01));
  });

  testWidgets("a window's frame keeps the shape of the monitor", (tester) async {
    final display = tester.view.display.size;
    final picture = await pictureOf(tester);

    expect(picture.width / picture.height, closeTo(display.width / display.height, 0.01));
  });
}
