// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../../l10n/app_localizations.dart';
import '../../domain/glossary.dart';

/// What a list of one [GlossaryKind] is called and how its two halves are
/// labelled, in the interface language.
class GlossaryKindTexts {
  const GlossaryKindTexts({
    required this.label,
    required this.note,
    required this.sourceLabel,
    required this.readingLabel,
  });

  factory GlossaryKindTexts.of(AppLocalizations l10n, GlossaryKind kind) => switch (kind) {
    GlossaryKind.phrase => GlossaryKindTexts(
      label: l10n.glossaryPhrases,
      note: l10n.glossaryPhrasesNote,
      sourceLabel: l10n.glossaryPhraseSource,
      readingLabel: l10n.glossaryPhraseReading,
    ),
    GlossaryKind.name => GlossaryKindTexts(
      label: l10n.glossaryNames,
      note: l10n.glossaryNamesNote,
      sourceLabel: l10n.glossaryNameSource,
      readingLabel: l10n.glossaryNameReading,
    ),
    GlossaryKind.word => GlossaryKindTexts(
      label: l10n.glossaryWords,
      note: l10n.glossaryWordsNote,
      sourceLabel: l10n.glossaryWordSource,
      readingLabel: l10n.glossaryWordReading,
    ),
  };

  final String label;
  final String note;
  final String sourceLabel;
  final String readingLabel;
}
