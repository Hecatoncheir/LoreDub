// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/app_settings.dart';

void main() {
  test('reads on-screen text in English unless it is the dubbing language', () {
    expect(const AppSettings().textLanguage, 'en');
    expect(
      const AppSettings(screenLanguage: 'de').textLanguage,
      'en',
      reason: 'German cannot be translated into Russian',
    );
    expect(const AppSettings(screenLanguage: 'ru').textLanguage, 'ru');
  });

  test('belongs to the screen, not to the game the pipeline listens to', () {
    // One field served both, so naming the screen's text as Russian named
    // the game's speech as Russian too -- and the graph, which draws the
    // dubbing of sound, redrew itself around a choice made on another page.
    const listening = AppSettings(sourceLanguage: 'ru');

    expect(listening.textLanguage, 'en');
    expect(const AppSettings(screenLanguage: 'ru').sourceLanguage, 'en');
  });
}
