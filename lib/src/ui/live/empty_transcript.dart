// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../domain/app_settings.dart';
import '../../domain/spoken_language.dart';
import '../../../l10n/app_localizations.dart';
import '../language_names.dart';
import '../theme.dart';

/// What the transcript card shows before its first line: where the lines
/// will come from and in which language they will be heard.
class EmptyTranscript extends StatelessWidget {
  const EmptyTranscript({super.key, required this.settings, required this.fromScreen});

  /// Which languages the lines will be read in and heard in: the pipeline
  /// ends in whichever is selected, so the hint says so rather than always
  /// naming Russian.
  final AppSettings settings;

  /// Whether this is the screen session's list rather than live dubbing's:
  /// the same card, fed by Windows OCR instead of whisper.
  final bool fromScreen;

  /// The chain the lines will come down, in a line.
  String _summary(AppLocalizations l10n) {
    // Whisper hands English over whatever the game speaks; the screen is
    // read in the language it is written in.
    final read = fromScreen ? settings.textLanguage : untranslatedDubbingLanguage;
    final heard = settings.targetLanguage;
    // Where nothing is translated there is no Marian in the line at all, and
    // naming it would describe a stage that is not loaded.
    return switch ((fromScreen, read == heard, read == untranslatedDubbingLanguage)) {
      (true, false, _) => l10n.pipelineSummaryOcr(spokenLanguageName(l10n, heard)),
      (true, true, true) => l10n.pipelineSummaryOcrDirect,
      (true, true, false) => l10n.pipelineSummaryOcrAsIs(spokenLanguageName(l10n, read)),
      (false, true, _) => l10n.pipelineSummaryDirect,
      (false, false, _) => l10n.pipelineSummary(spokenLanguageName(l10n, heard)),
    };
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    // The card either hands this a height to fill or grows with it, and
    // reaching for the height of a card that has none is asking for
    // infinity.
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: constraints.maxHeight.isFinite && constraints.maxHeight > 24
              ? constraints.maxHeight - 24
              : 0,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.subtitles_outlined,
                size: 42,
                color: context.colors.mutedInk,
              ),
              const SizedBox(height: 14),
              Text(AppLocalizations.of(context).emptyTranscript),
              const SizedBox(height: 6),
              Text(
                _summary(AppLocalizations.of(context)),
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: context.colors.mutedInk),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
