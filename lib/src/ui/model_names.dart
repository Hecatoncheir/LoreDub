// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../l10n/app_localizations.dart';
import '../data/services/model_catalog.dart';
import '../domain/model_package.dart';
import 'language_names.dart';

/// Names the packages for the reader. The catalogue holds identifiers, sizes
/// and URLs; what to call a package belongs to the translations.
String modelTitle(AppLocalizations l10n, ModelPackage model) => switch (model.kind) {
  ModelKind.recognition => l10n.modelWhisperTitle,
  ModelKind.translation => l10n.modelTranslationTitle(
    translationTargetName(l10n, model.language!),
  ),
  ModelKind.speech => l10n.modelVoiceTitle(
    voiceName(l10n, model.language!),
    model.version ?? '',
  ),
};

String modelDescription(AppLocalizations l10n, ModelPackage model) => switch (model.kind) {
  ModelKind.recognition => l10n.modelWhisperNote,
  ModelKind.translation => l10n.modelTranslationNote,
  // The Russian package ships several voices worth naming; the others do not.
  ModelKind.speech =>
    model.id == speechModelFor('ru')?.id
        ? l10n.modelVoiceNoteRu
        : l10n.modelVoiceNote(voiceSpeechName(l10n, model.language!)),
};
