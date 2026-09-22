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

  test('is picked with the dubbing language, as the models screen shows it', () {
    final russian = const AppSettings(
      targetLanguage: 'en',
    ).withScreenLanguages(text: 'ru', dubbing: 'ru');
    expect((russian.screenLanguage, russian.targetLanguage), ('ru', 'ru'));

    // Back to English, the voices are English again, and so is the models
    // screen -- which a text language alone left on Russian.
    final english = russian.withScreenLanguages(text: 'en', dubbing: 'en');
    expect((english.screenLanguage, english.targetLanguage), ('en', 'en'));

    final translated = english.withScreenLanguages(text: 'en', dubbing: 'ru');
    expect((translated.textLanguage, translated.targetLanguage), ('en', 'ru'));
  });

  test('reads text left in a dubbing language picked away from as English', () {
    const russian = AppSettings(targetLanguage: 'ru', screenLanguage: 'ru');

    expect(russian.withTargetLanguage('en').screenLanguage, 'en', reason: 'no voice reads it');
    expect(russian.withTargetLanguage('ru').screenLanguage, 'ru');
    expect(
      const AppSettings(targetLanguage: 'en').withTargetLanguage('ru').screenLanguage,
      'en',
      reason: 'English is translated into the new one',
    );
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
