// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../../../l10n/app_localizations.dart';
import '../../../domain/pipeline_graph.dart';

/// What cutting a line parts with. Every line that means something carries
/// a badge to cut it by: what feeds the pipeline, the translator, the cast
/// in the mix, who reads whom, and the note that the game speaks a card. The
/// lines between stages that say nothing on their own -- the voice into the
/// mix, the mix into the output -- carry none, there being nothing to answer
/// with.
enum LinkCut {
  /// The way into the pipeline, which comes apart the way a substitution
  /// does, by the button on the line itself.
  route,

  /// The cast comes out of the mix whole, so any of its lines will do.
  cast,

  /// The dashed line that counts a card among the voices of the game.
  heard,

  /// Either half of the translator's line: cutting it dubs into English,
  /// which is the language whisper hands over anyway.
  translation,

  /// The line that steps over the translator, whose cut puts it back.
  translationBack,

  /// One card reading another, which gives the card its own part back.
  reader;

  /// What cutting [link] would part with, or null for a line with no badge.
  static LinkCut? of(PipelineLink link) {
    final from = link.from.socket;
    final to = link.to.socket;
    if (from == PipelineSocket.gameAudio) return route;
    if (to == PipelineSocket.mixCast) return cast;
    if (to == PipelineSocket.characterIn) return heard;
    if (to == PipelineSocket.translationIn || from == PipelineSocket.translatedText) {
      return translation;
    }
    if (from == PipelineSocket.speechText && to == PipelineSocket.voiceIn) return translationBack;
    if (from == PipelineSocket.characterVoice && to == PipelineSocket.readBy) return reader;
    return null;
  }

  /// What the badge says it does, in the interface language.
  String describe(AppLocalizations l10n) => switch (this) {
    route => l10n.pipelineCutRoute,
    cast => l10n.pipelineCutCast,
    heard => l10n.pipelineCutHeard,
    translation => l10n.pipelineCutTranslation,
    translationBack => l10n.pipelineCutTranslationBack,
    reader => l10n.pipelineCutLink,
  };
}
