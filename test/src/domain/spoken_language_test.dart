// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/l10n/app_localizations.dart';
import 'package:lore_dub/src/domain/spoken_language.dart';
import 'package:lore_dub/src/ui/language_names.dart';

void main() {
  test('offers the languages game audio usually carries', () {
    expect(spokenLanguages, containsAll(<String>['en', 'ja', 'de', 'fr', 'es', 'zh', 'ru']));
  });

  test('every entry is a code whisper accepts', () {
    for (final language in spokenLanguages) {
      expect(language, matches(RegExp(r'^[a-z]{2,3}$')));
    }
  });

  test('lists each language once', () {
    expect(spokenLanguages.toSet(), hasLength(spokenLanguages.length));
  });

  test('never reports the auto sentinel as a language of its own', () {
    expect(isSupportedSpokenLanguage(autoSpokenLanguage), isFalse);
    expect(isSupportedSpokenLanguage(fallbackSpokenLanguage), isTrue);
    expect(isSupportedSpokenLanguage('klingon'), isFalse);
  });

  test('offers Russian first and English as the interface languages', () {
    expect(interfaceLanguages, ['ru', 'en']);
    expect(defaultInterfaceLanguage, 'ru');
  });

  group('names', () {
    late AppLocalizations ru;
    late AppLocalizations en;

    setUp(() async {
      ru = await AppLocalizations.delegate.load(const Locale('ru'));
      en = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('writes every offered language out in both interface languages', () {
      for (final language in spokenLanguages) {
        expect(spokenLanguageName(ru, language), isNotEmpty, reason: language);
        expect(spokenLanguageName(en, language), isNotEmpty, reason: language);
        expect(
          spokenLanguageName(ru, language),
          isNot(language.toUpperCase()),
          reason: '$language has no Russian name',
        );
        expect(
          spokenLanguageName(en, language),
          isNot(language.toUpperCase()),
          reason: '$language has no English name',
        );
      }
    });

    test('follows the interface language', () {
      expect(spokenLanguageName(ru, 'ja'), 'Японский');
      expect(spokenLanguageName(en, 'ja'), 'Japanese');
    });

    test('shows a detected language the list does not name as its code', () {
      // whisper knows far more languages than the picker offers; naming such
      // a detection "Английский" would be a lie.
      expect(spokenLanguageName(ru, 'hu'), 'HU');
      expect(spokenLanguageName(en, 'hu'), 'HU');
    });
  });
}
