// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../../../l10n/app_localizations.dart';
import '../../../domain/pipeline_graph.dart';

/// What cutting a line parts with. Every line that means something carries
/// a badge to cut it by: what feeds the pipeline, the voices behind the
/// screen, the translator, the cast in the mix, who reads whom, the note
/// that the game speaks a card, and a pack of the glossary in the line of
/// text. The lines between stages that say nothing on their own -- the
/// voice into the mix, the mix into the output -- carry none, there being
/// nothing to answer with.
enum LinkCut {
  /// The way into the pipeline, which comes apart the way a substitution
  /// does, by the button on the line itself.
  route,

  /// Either half of the way through the Screen page's character detection,
  /// after which every line is read in the one voice.
  voices,

  /// The cast comes out of the mix whole, so any of its lines will do.
  cast,

  /// The dashed line that counts a card among the voices of the game.
  heard,

  /// Either half of the translator's line: cutting it dubs into English,
  /// which is the language whisper hands over anyway.
  translation,

  /// Either half of the Screen page's translator's line: cutting it reads
  /// the text on the screen as it is, in the dubbing language.
  screenTranslation,

  /// The line that steps over the translator, whose cut puts it back.
  translationBack,

  /// One card reading another, which gives the card its own part back.
  reader,

  /// Either line of a pack of the glossary, which takes the pack out of the
  /// line of text and switches it off.
  glossary;

  /// What cutting [link], drawn on [scheme], would part with, or null for a
  /// line with no badge.
  ///
  /// A pack's lines are asked about before the translator's, a pack standing
  /// next to the translator sharing a socket with the translator's line, and
  /// the detection's before the way into Эфир's pipeline, which leaves the
  /// same socket of the game's sound.
  static LinkCut? of(PipelineLink link, {PipelineScheme scheme = PipelineScheme.live}) =>
      switch ((link.from.socket, link.to.socket)) {
        (_, PipelineSocket.glossaryIn) || (PipelineSocket.glossaryOut, _) => glossary,
        (_, PipelineSocket.detectionIn) || (PipelineSocket.detectedSpeaker, _) => voices,
        (PipelineSocket.gameAudio, _) => route,
        (_, PipelineSocket.mixCast) => cast,
        (_, PipelineSocket.characterIn) => heard,
        (_, PipelineSocket.translationIn) || (PipelineSocket.translatedText, _) =>
          scheme == PipelineScheme.screen ? screenTranslation : translation,
        (PipelineSocket.speechText || PipelineSocket.screenText, PipelineSocket.voiceIn) =>
          translationBack,
        (PipelineSocket.characterVoice, PipelineSocket.readBy) => reader,
        _ => null,
      };

  /// What the badge says it does, in the interface language.
  String describe(AppLocalizations l10n) => switch (this) {
    route => l10n.pipelineCutRoute,
    voices => l10n.pipelineCutVoices,
    cast => l10n.pipelineCutCast,
    heard => l10n.pipelineCutHeard,
    translation => l10n.pipelineCutTranslation,
    screenTranslation => l10n.pipelineCutScreenTranslation,
    translationBack => l10n.pipelineCutTranslationBack,
    reader => l10n.pipelineCutLink,
    glossary => l10n.pipelineCutGlossary,
  };
}
