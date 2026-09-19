// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../../../l10n/app_localizations.dart';
import '../../../data/services/playback_scheduler.dart';
import '../../../domain/app_settings.dart';
import '../../../domain/compute_device.dart';
import '../../../domain/pipeline_graph.dart';
import '../../../domain/spoken_language.dart';
import '../../compute_names.dart';
import '../../language_names.dart';
import '../../model_names.dart';
import 'pipeline_facts.dart';

/// What a node writes on itself: its name, one line of what it is set to,
/// and a mark of where it runs -- worked out once from the configuration.
class NodeLabels {
  const NodeLabels({required this.title, required this.headline, required this.note});

  factory NodeLabels.of(
    AppLocalizations l10n,
    PipelineNode node,
    PipelineFacts facts,
    ComputeAvailability availability,
  ) {
    final reading = _Reading(l10n, node, facts, availability);
    return NodeLabels(title: reading.title(), headline: reading.headline(), note: reading.note());
  }

  /// The card's own name, which is all a socket's label needs. Cheaper
  /// than reading the whole card: the other two lines ask the settings,
  /// the packages and the machine what the stage is set to.
  static String titleOf(AppLocalizations l10n, PipelineNode node, PipelineFacts facts) =>
      _Reading(l10n, node, facts, const ComputeAvailability()).title();

  final String title;
  final String headline;
  final String note;
}

/// One node read against the configuration.
class _Reading {
  const _Reading(this.l10n, this.node, this.facts, this.availability);

  final AppLocalizations l10n;
  final PipelineNode node;
  final PipelineFacts facts;
  final ComputeAvailability availability;

  AppSettings get _settings => facts.settings;

  String title() => switch (node.kind) {
    PipelineNodeKind.source => l10n.pipelineNodeSource,
    PipelineNodeKind.recognition => l10n.pipelineNodeRecognition,
    PipelineNodeKind.translation => l10n.pipelineNodeTranslation,
    PipelineNodeKind.voice => l10n.pipelineNodeVoice,
    PipelineNodeKind.mix => l10n.pipelineNodeMix,
    PipelineNodeKind.output => l10n.pipelineNodeOutput,
    PipelineNodeKind.character => facts.character(node.characterId)?.name ?? l10n.charactersNewName,
  };

  /// What the node is set to, in one line.
  String headline() => switch (node.kind) {
    PipelineNodeKind.source => _source(),
    PipelineNodeKind.recognition => switch (facts.selection.recognition?.model) {
      final model? => whisperShortName(model),
      _ => l10n.pipelineNoModel,
    },
    PipelineNodeKind.translation => _translation(),
    PipelineNodeKind.voice => switch (_settings.voiceMode) {
      VoiceMode.original => l10n.voiceOriginal,
      VoiceMode.automatic => l10n.voiceAutomatic,
      VoiceMode.chosen => _chosenVoice(),
    },
    PipelineNodeKind.mix =>
      _settings.overlapVoices
          ? l10n.pipelineMixVoices(overlappingVoices)
          : l10n.pipelineMixOneVoice,
    PipelineNodeKind.output => l10n.pipelineOutputDefault,
    PipelineNodeKind.character => _characterHeadline(),
  };

  /// Capturing the whole output needs no game, so none is asked for here:
  /// what is listened to then is the device itself.
  String _source() => _settings.audioCaptureSource == AudioCaptureSource.system
      ? l10n.pipelineOutputDefault
      : facts.process?.name ?? l10n.pipelineNoProcess;

  /// Whisper is run with -tr, so what reaches the translator is English
  /// whatever the game speaks; the language Live listens in says nothing
  /// about this stage. Dubbing into English stands the stage aside: whisper
  /// has handed English over and the line is read as it arrived.
  String _translation() {
    if (_settings.targetLanguage == untranslatedDubbingLanguage) return l10n.pipelineNoTranslation;
    return '${spokenLanguageName(l10n, fallbackSpokenLanguage)}'
        ' → ${translationTargetName(l10n, _settings.targetLanguage)}';
  }

  /// The voice a fixed choice reads every line in, named as the picker names
  /// it rather than by its bare identifier.
  String _chosenVoice() {
    final chosen = facts.selection.voice;
    for (final option in facts.selection.availableVoices) {
      if (option.id == chosen) return voiceLabel(l10n, option);
    }
    return chosen;
  }

  String _characterHeadline() {
    final reader = facts.character(facts.character(node.characterId)?.voicedBy);
    return reader == null ? l10n.charactersOwnVoice : l10n.pipelineReadBy(reader.name);
  }

  String _device(ComputeStage stage) =>
      computeBackendName(l10n, facts.backendOf(stage, availability)).toUpperCase();

  /// Where the node runs, or what it runs as, in capitals.
  String note() => switch (node.kind) {
    PipelineNodeKind.source =>
      _settings.audioCaptureSource == AudioCaptureSource.process
          ? l10n.sourceProcess.toUpperCase()
          : l10n.sourceSystem.toUpperCase(),
    PipelineNodeKind.recognition => _device(ComputeStage.recognition),
    PipelineNodeKind.translation => _device(ComputeStage.translation),
    PipelineNodeKind.voice =>
      facts.selection.clonesVoice
          ? _device(ComputeStage.voiceConversion)
          : _device(ComputeStage.speech),
    PipelineNodeKind.mix =>
      _settings.overlapVoices
          ? l10n.pipelineMixOverlapping.toUpperCase()
          : l10n.pipelineMixInTurn.toUpperCase(),
    PipelineNodeKind.output =>
      l10n.pipelineOutputOriginal((_settings.originalVolume * 100).round()).toUpperCase(),
    PipelineNodeKind.character => _characterNote(),
  };

  String _characterNote() {
    final character = facts.character(node.characterId);
    if (character == null) return '';
    if (!_settings.originalVoice) return l10n.pipelineCharacterNeedsOriginal;
    return character.vector.isEmpty
        ? l10n.charactersNoVoice
        : l10n.charactersHeard(character.seconds.toStringAsFixed(1));
  }
}
