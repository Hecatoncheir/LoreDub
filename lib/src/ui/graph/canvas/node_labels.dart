// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../../../l10n/app_localizations.dart';
import '../../../domain/speech_pace.dart';
import '../../../domain/app_settings.dart';
import '../../../domain/compute_device.dart';
import '../../../domain/glossary.dart';
import '../../../domain/pipeline_graph.dart';
import '../../../domain/spoken_language.dart';
import '../../compute_names.dart';
import '../../language_names.dart';
import '../../model_names.dart';
import 'pipeline_facts.dart';

/// What a node writes on itself: its name, one line of what it is set to,
/// and a mark of where it runs -- worked out once from the configuration.
class NodeLabels {
  const NodeLabels({
    required this.title,
    required this.headline,
    required this.note,
    String? name,
  }) : name = name ?? title;

  factory NodeLabels.of(
    AppLocalizations l10n,
    PipelineNode node,
    PipelineFacts facts,
    ComputeAvailability availability,
  ) {
    final reading = _Reading(l10n, node, facts, availability);
    return NodeLabels(
      title: reading.title(),
      headline: reading.headline(),
      note: reading.note(),
      name: reading.name(),
    );
  }

  /// The card's name as a reader hears it, which is all a socket's label
  /// needs. Cheaper than reading the whole card: the other two lines ask
  /// the settings, the packages and the machine what the stage is set to.
  static String titleOf(AppLocalizations l10n, PipelineNode node, PipelineFacts facts) =>
      _Reading(l10n, node, facts, const ComputeAvailability()).name();

  final String title;
  final String headline;
  final String note;

  /// What a reader hears the card called. Its [title], but for a pack of the
  /// glossary the pack's name as well: several of them are titled alike, and
  /// a reader cannot see the line under the title that tells them apart.
  final String name;
}

/// One node read against the configuration.
class _Reading {
  const _Reading(this.l10n, this.node, this.facts, this.availability);

  final AppLocalizations l10n;
  final PipelineNode node;
  final PipelineFacts facts;
  final ComputeAvailability availability;

  AppSettings get _settings => facts.settings;

  /// Whether the node is drawn on the Screen page's scheme, whose shared
  /// stages say what the screen session does with them.
  bool get _onScreen => node.scheme == PipelineScheme.screen;

  /// Whether the translator of the node's scheme stands in the line.
  bool get _translates => _onScreen ? _settings.screenTranslates : _settings.translates;

  /// Whether the Screen page's voices are listened for, and can be: it is
  /// the converter that hears them.
  bool get _hearsVoices => _settings.screenVoices && facts.selection.measuresVoices;

  String title() => switch (node.kind) {
    PipelineNodeKind.source => l10n.pipelineNodeSource,
    PipelineNodeKind.recognition => l10n.pipelineNodeRecognition,
    PipelineNodeKind.translation => l10n.pipelineNodeTranslation,
    PipelineNodeKind.voice => l10n.pipelineNodeVoice,
    PipelineNodeKind.mix => l10n.pipelineNodeMix,
    PipelineNodeKind.output => l10n.pipelineNodeOutput,
    PipelineNodeKind.character => facts.character(node.characterId)?.name ?? l10n.charactersNewName,
    PipelineNodeKind.glossary => l10n.pipelineNodeGlossary,
    PipelineNodeKind.screen => l10n.pipelineNodeScreen,
    PipelineNodeKind.detection => l10n.pipelineNodeDetection,
  };

  /// The [title], and for a pack the pack it reads.
  String name() => switch (facts.pack(node.packId)) {
    final pack? when node.kind == PipelineNodeKind.glossary => l10n.pipelineGlossaryNamed(
      pack.name,
    ),
    _ => title(),
  };

  /// What the node is set to, in one line.
  String headline() => switch (node.kind) {
    PipelineNodeKind.source => _source(),
    PipelineNodeKind.recognition => switch (facts.selection.recognition?.model) {
      final model? => whisperShortName(model),
      _ => l10n.pipelineNoModel,
    },
    PipelineNodeKind.translation => _translation(),
    PipelineNodeKind.voice => _voice(),
    PipelineNodeKind.mix =>
      _settings.overlapVoices && !_onScreen
          ? l10n.pipelineMixVoices(overlappingVoices)
          : l10n.pipelineMixOneVoice,
    PipelineNodeKind.output => l10n.pipelineOutputDefault,
    PipelineNodeKind.character => _characterHeadline(),
    // The pack is the node's one setting, as the model is whisper's.
    PipelineNodeKind.glossary => facts.pack(node.packId)?.name ?? l10n.pipelineGlossaryNoPack,
    PipelineNodeKind.screen => _screen(),
    PipelineNodeKind.detection => switch (facts.selection.voiceConverter) {
      final converter? when converter.installed => converterShortName(l10n, converter.model),
      _ => l10n.pipelineNoConverter,
    },
  };

  /// Capturing the whole output needs no game, so none is asked for here:
  /// what is listened to then is the device itself. The Screen page listens
  /// to the game it reads, and to nothing else.
  String _source() => _settings.audioCaptureSource == AudioCaptureSource.system && !_onScreen
      ? l10n.pipelineOutputDefault
      : facts.process?.name ?? l10n.pipelineNoProcess;

  /// What the screen is read off: the game's window, or everything the
  /// monitors show.
  String _screen() => _settings.readsWholeScreen
      ? l10n.screenSourceScreen
      : facts.process?.name ?? l10n.pipelineNoProcess;

  /// Whisper is run with -tr, so what reaches the translator is English
  /// whatever the game speaks; the language Live listens in says nothing
  /// about this stage. The Screen page's text is English when it is
  /// translated at all. Dubbing into English -- or reading the screen in
  /// the dubbing language -- stands the stage aside: the line is read as it
  /// arrived.
  String _translation() {
    if (!_translates) return l10n.pipelineNoTranslation;
    return '${spokenLanguageName(l10n, fallbackSpokenLanguage)}'
        ' → ${spokenLanguageName(l10n, _settings.targetLanguage)}';
  }

  /// How the voice is chosen. The Screen page reads every line in the one
  /// voice picked for it, a line on a screen having no sound of its own to
  /// follow a speaker by.
  String _voice() {
    if (_onScreen) return _chosenVoice();
    return switch (_settings.voiceMode) {
      VoiceMode.original => l10n.voiceOriginal,
      VoiceMode.automatic => l10n.voiceAutomatic,
      VoiceMode.chosen => _chosenVoice(),
    };
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
    PipelineNodeKind.source => _sourceNote(),
    PipelineNodeKind.recognition => _device(ComputeStage.recognition),
    PipelineNodeKind.translation => _device(ComputeStage.translation),
    PipelineNodeKind.voice => _voiceNote(),
    PipelineNodeKind.mix =>
      _settings.overlapVoices && !_onScreen
          ? l10n.pipelineMixOverlapping.toUpperCase()
          : l10n.pipelineMixInTurn.toUpperCase(),
    PipelineNodeKind.output =>
      l10n.pipelineOutputOriginal((_settings.originalVolume * 100).round()).toUpperCase(),
    PipelineNodeKind.character => _characterNote(),
    PipelineNodeKind.glossary => _glossaryNote().toUpperCase(),
    PipelineNodeKind.screen =>
      l10n.pipelineScreenOcr(spokenLanguageName(l10n, _settings.textLanguage)).toUpperCase(),
    PipelineNodeKind.detection => _device(ComputeStage.voiceConversion),
  };

  /// The game alone, or the whole output. The Screen page's is the game.
  String _sourceNote() => _settings.audioCaptureSource == AudioCaptureSource.process || _onScreen
      ? l10n.sourceProcess.toUpperCase()
      : l10n.sourceSystem.toUpperCase();

  /// Where the voice runs: the converter's device where it lays a timbre
  /// over the voice, the speech model's otherwise.
  String _voiceNote() {
    final converts = _onScreen ? _hearsVoices : facts.selection.clonesVoice;
    return converts ? _device(ComputeStage.voiceConversion) : _device(ComputeStage.speech);
  }

  /// What of the pack the text it reads can meet, and how many entries
  /// that is: where a stage says where it runs, a pack says what it puts
  /// right -- or, switched off, that the text passes it by.
  String _glossaryNote() {
    final kinds = node.feed?.kinds(translates: _translates) ?? const <GlossaryKind>{};
    if (kinds.isEmpty) return l10n.pipelineGlossaryNoteNothing;
    if (!node.active) return l10n.pipelineGlossaryNotePassing;
    final count = facts.pack(node.packId)?.countOf(kinds) ?? 0;
    if (kinds.contains(GlossaryKind.phrase)) return l10n.pipelineGlossaryNotePhrases(count);
    if (kinds.contains(GlossaryKind.name)) return l10n.pipelineGlossaryNoteNamesWords(count);
    return l10n.pipelineGlossaryNoteWords(count);
  }

  /// What the card's voice was measured from -- or, where nothing would
  /// hear it speak, what it waits for: the original voice on Эфир, the
  /// character detection on the Screen page.
  String _characterNote() {
    final character = facts.character(node.characterId);
    if (character == null) return '';
    if (_onScreen && !_hearsVoices) return l10n.pipelineCharacterNeedsDetection;
    if (!_onScreen && !_settings.originalVoice) return l10n.pipelineCharacterNeedsOriginal;
    return character.vector.isEmpty
        ? l10n.charactersNoVoice
        : l10n.charactersHeard(character.seconds.toStringAsFixed(1));
  }
}
