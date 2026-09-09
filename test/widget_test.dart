// Copyright (c) 2026 GameLingo contributors.
// SPDX-License-Identifier: MIT

import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:game_lingo/src/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders the desktop shell', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const GameLingoBootstrap());
    await tester.pump();

    expect(find.text('GameLingo'), findsOneWidget);
    expect(find.text('Перевод игры'), findsOneWidget);
    expect(find.text('Эфир'), findsOneWidget);
  });
}
