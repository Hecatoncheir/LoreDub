// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../domain/spoken_language.dart';
import '../../../l10n/app_localizations.dart';
import '../language_names.dart';
import '../theme.dart';

/// What the transcript card shows before its first line: where the lines
/// will come from and in which language they will be heard.
class EmptyTranscript extends StatelessWidget {
  const EmptyTranscript({super.key, required this.targetLanguage, required this.fromScreen});

  /// The pipeline ends in whichever language is selected, so the hint says so
  /// rather than always naming Russian.
  final String targetLanguage;

  /// Whether this is the screen session's list rather than live dubbing's:
  /// the same card, fed by Windows OCR instead of whisper.
  final bool fromScreen;

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
                // Dubbing into English has no translator in the line at all:
                // what whisper hands over is the language it is read in, and
                // naming Marian here would describe a stage that is not
                // loaded.
                switch ((fromScreen, targetLanguage == untranslatedDubbingLanguage)) {
                  (true, true) => AppLocalizations.of(context).pipelineSummaryOcrDirect,
                  (false, true) => AppLocalizations.of(context).pipelineSummaryDirect,
                  (true, false) => AppLocalizations.of(context).pipelineSummaryOcr(
                    spokenLanguageName(AppLocalizations.of(context), targetLanguage),
                  ),
                  (false, false) => AppLocalizations.of(context).pipelineSummary(
                    spokenLanguageName(AppLocalizations.of(context), targetLanguage),
                  ),
                },
                style: TextStyle(color: context.colors.mutedInk),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
