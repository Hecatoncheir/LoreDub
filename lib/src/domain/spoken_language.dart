// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// A language whisper.cpp can be told to expect in the game audio.
class SpokenLanguage {
  const SpokenLanguage(this.code, this.title);

  /// What `whisper-cli -l` expects.
  final String code;

  final String title;
}

/// Naming the language is worth an option: detecting it costs a full extra
/// encoder pass, and a short or noisy first phrase can be detected wrong,
/// which would then apply to the whole session.
const spokenLanguages = <SpokenLanguage>[
  SpokenLanguage('en', 'Английский'),
  SpokenLanguage('ar', 'Арабский'),
  SpokenLanguage('es', 'Испанский'),
  SpokenLanguage('it', 'Итальянский'),
  SpokenLanguage('zh', 'Китайский'),
  SpokenLanguage('ko', 'Корейский'),
  SpokenLanguage('de', 'Немецкий'),
  SpokenLanguage('nl', 'Нидерландский'),
  SpokenLanguage('pl', 'Польский'),
  SpokenLanguage('pt', 'Португальский'),
  SpokenLanguage('ru', 'Русский'),
  SpokenLanguage('tr', 'Турецкий'),
  SpokenLanguage('uk', 'Украинский'),
  SpokenLanguage('fr', 'Французский'),
  SpokenLanguage('cs', 'Чешский'),
  SpokenLanguage('sv', 'Шведский'),
  SpokenLanguage('ja', 'Японский'),
];

/// The value passed to whisper.cpp when the language is detected per session.
const autoSpokenLanguage = 'auto';

const fallbackSpokenLanguage = 'en';

bool isSupportedSpokenLanguage(String code) =>
    spokenLanguages.any((language) => language.code == code);

String spokenLanguageTitle(String code) => spokenLanguages
    .firstWhere(
      (language) => language.code == code,
      orElse: () => const SpokenLanguage(fallbackSpokenLanguage, 'Английский'),
    )
    .title;
