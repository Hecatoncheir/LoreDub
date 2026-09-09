// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpLoreDub(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const LoreDubBootstrap());
    await tester.pump();
  }

  testWidgets('renders the branded desktop shell', (tester) async {
    await pumpLoreDub(tester, const Size(1280, 720));

    expect(find.text('LoreDub'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Перевод игры'), findsOneWidget);
    expect(find.text('Эфир'), findsOneWidget);
    expect(find.text('01  /  LIVE VOICE'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('uses compact navigation in a narrow window', (tester) async {
    await pumpLoreDub(tester, const Size(760, 720));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Эфир'), findsOneWidget);
    expect(find.text('Модели'), findsOneWidget);
    expect(find.text('Настройки'), findsOneWidget);
  });
}
