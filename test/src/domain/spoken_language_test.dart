// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/spoken_language.dart';

void main() {
  test('offers the languages game audio usually carries', () {
    final codes = spokenLanguages.map((language) => language.code);

    expect(codes, containsAll(<String>['en', 'ja', 'de', 'fr', 'es', 'zh', 'ru']));
  });

  test('every entry carries a code whisper accepts and a readable title', () {
    for (final language in spokenLanguages) {
      expect(language.code, matches(RegExp(r'^[a-z]{2,3}$')), reason: language.title);
      expect(language.title.trim(), isNotEmpty, reason: language.code);
    }
  });

  test('lists each language once', () {
    final codes = spokenLanguages.map((language) => language.code).toList();

    expect(codes.toSet(), hasLength(codes.length));
  });

  test('never reports the auto sentinel as a language of its own', () {
    expect(isSupportedSpokenLanguage(autoSpokenLanguage), isFalse);
    expect(isSupportedSpokenLanguage(fallbackSpokenLanguage), isTrue);
    expect(isSupportedSpokenLanguage('klingon'), isFalse);
  });

  test('falls back to a readable title for an unknown code', () {
    expect(spokenLanguageTitle('ja'), 'Японский');
    expect(spokenLanguageTitle('klingon'), 'Английский');
  });
}
