// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../l10n/app_localizations.dart';

/// Writes language codes out for the reader. The catalogue and the domain
/// deal in codes; only this layer knows what to call them, and in which
/// language of the interface.
String spokenLanguageName(AppLocalizations l10n, String code) => switch (code) {
  'ar' => l10n.language_ar,
  'cs' => l10n.language_cs,
  'de' => l10n.language_de,
  'en' => l10n.language_en,
  'es' => l10n.language_es,
  'fr' => l10n.language_fr,
  'it' => l10n.language_it,
  'ja' => l10n.language_ja,
  'ko' => l10n.language_ko,
  'nl' => l10n.language_nl,
  'pl' => l10n.language_pl,
  'pt' => l10n.language_pt,
  'ru' => l10n.language_ru,
  'sv' => l10n.language_sv,
  'tr' => l10n.language_tr,
  'uk' => l10n.language_uk,
  'zh' => l10n.language_zh,
  // whisper knows far more languages than the picker offers, so a detected
  // code with no name is shown as the code rather than as a wrong name.
  _ => code.toUpperCase(),
};

/// The dubbing language as it reads inside a title such as "English → German".
String translationTargetName(AppLocalizations l10n, String code) => switch (code) {
  'de' => l10n.translationTarget_de,
  'es' => l10n.translationTarget_es,
  'fr' => l10n.translationTarget_fr,
  'ru' => l10n.translationTarget_ru,
  'uk' => l10n.translationTarget_uk,
  _ => spokenLanguageName(l10n, code),
};

String voiceName(AppLocalizations l10n, String code) => switch (code) {
  'de' => l10n.voiceName_de,
  'es' => l10n.voiceName_es,
  'fr' => l10n.voiceName_fr,
  'ru' => l10n.voiceName_ru,
  'uk' => l10n.voiceName_uk,
  _ => spokenLanguageName(l10n, code),
};

String voiceSpeechName(AppLocalizations l10n, String code) => switch (code) {
  'de' => l10n.voiceSpeech_de,
  'es' => l10n.voiceSpeech_es,
  'fr' => l10n.voiceSpeech_fr,
  'uk' => l10n.voiceSpeech_uk,
  _ => spokenLanguageName(l10n, code),
};

/// Interface languages name themselves, the way language pickers everywhere
/// do: someone looking for English should not have to read Russian to find it.
String interfaceLanguageName(String code) => switch (code) {
  'ru' => 'Русский',
  'en' => 'English',
  _ => code.toUpperCase(),
};
