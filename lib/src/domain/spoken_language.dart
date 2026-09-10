// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// Languages the interface itself is available in. Russian is the source the
/// English wording is translated from, and the default.
const interfaceLanguages = ['ru', 'en'];

const defaultInterfaceLanguage = 'ru';

/// Languages whisper.cpp can be told to expect in the game audio, in the
/// order they are offered. Their names live in the translations: this layer
/// knows the codes `whisper-cli -l` expects, not how to write them out.
///
/// Naming the language is worth an option: detecting it costs a full extra
/// encoder pass, and a short or noisy first phrase can be detected wrong,
/// which would then apply to the whole session.
const spokenLanguages = <String>[
  'en',
  'ar',
  'es',
  'it',
  'zh',
  'ko',
  'de',
  'nl',
  'pl',
  'pt',
  'ru',
  'tr',
  'uk',
  'fr',
  'cs',
  'sv',
  'ja',
];

/// The value passed to whisper.cpp when the language is detected per session.
const autoSpokenLanguage = 'auto';

const fallbackSpokenLanguage = 'en';

bool isSupportedSpokenLanguage(String code) => spokenLanguages.contains(code);
