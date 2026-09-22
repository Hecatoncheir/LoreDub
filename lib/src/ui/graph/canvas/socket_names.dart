// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../../../l10n/app_localizations.dart';
import '../../../domain/pipeline_graph.dart';

/// What a socket carries, in one word -- the same word the card writes
/// beside it (`NodePortRows`), said again for a reader that cannot see
/// which row a dot sits on.
String socketName(AppLocalizations l10n, PipelineSocket socket) => switch (socket) {
  PipelineSocket.gameAudio => l10n.pipelineSocketGameAudio,
  PipelineSocket.speechIn => l10n.pipelineSocketSpeech,
  PipelineSocket.speechText ||
  PipelineSocket.translationIn ||
  PipelineSocket.translatedText ||
  PipelineSocket.voiceIn ||
  PipelineSocket.glossaryIn ||
  PipelineSocket.glossaryOut => l10n.pipelineSocketText,
  PipelineSocket.voiceAudio ||
  PipelineSocket.mixIn ||
  PipelineSocket.mixOut ||
  PipelineSocket.streamIn => l10n.pipelineSocketAudio,
  PipelineSocket.voiceCast || PipelineSocket.mixCast => l10n.pipelineSocketCast,
  PipelineSocket.characterIn => l10n.pipelineSocketCharacter,
  PipelineSocket.readBy || PipelineSocket.characterVoice => l10n.pipelineSocketVoice,
};
