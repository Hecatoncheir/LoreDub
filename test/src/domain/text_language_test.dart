// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/app_settings.dart';

void main() {
  test('reads on-screen text in English unless it is the dubbing language', () {
    expect(const AppSettings().textLanguage, 'en');
    expect(
      const AppSettings(sourceLanguage: 'de').textLanguage,
      'en',
      reason: 'German cannot be translated into Russian',
    );
    expect(const AppSettings(sourceLanguage: 'ru').textLanguage, 'ru');
    expect(
      const AppSettings(sourceLanguage: 'ru', detectSourceLanguage: false).textLanguage,
      'ru',
    );
  });
}
