// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/compute_device.dart';
import '../../../domain/pipeline_graph.dart';
import '../canvas/pipeline_facts.dart';
import 'character_node_fields.dart';
import 'glossary_node_fields.dart';
import 'inspector_note.dart';
import 'mix_node_fields.dart';
import 'output_node_fields.dart';
import 'recognition_node_fields.dart';
import 'source_node_fields.dart';
import 'translation_node_fields.dart';
import 'voice_node_fields.dart';

/// The controls of the node the panel opened on, by its kind.
class NodeInspectorFields extends StatelessWidget {
  const NodeInspectorFields({
    super.key,
    required this.node,
    required this.facts,
    required this.availability,
    required this.chained,
  });

  final PipelineNode node;
  final PipelineFacts facts;
  final ComputeAvailability availability;
  final Set<String> chained;

  @override
  Widget build(BuildContext context) => switch (node.kind) {
    PipelineNodeKind.source => SourceNodeFields(facts: facts),
    PipelineNodeKind.recognition => RecognitionNodeFields(facts: facts, availability: availability),
    PipelineNodeKind.translation => TranslationNodeFields(facts: facts, availability: availability),
    PipelineNodeKind.voice => VoiceNodeFields(facts: facts, availability: availability),
    PipelineNodeKind.mix => MixNodeFields(facts: facts),
    PipelineNodeKind.output => OutputNodeFields(facts: facts),
    PipelineNodeKind.character => switch (facts.character(node.characterId)) {
      final character? => CharacterNodeFields(
        node: node,
        character: character,
        facts: facts,
        chained: chained.contains(character.id),
      ),
      null => InspectorNote(text: AppLocalizations.of(context).charactersEmpty),
    },
    PipelineNodeKind.glossary => GlossaryNodeFields(node: node, facts: facts),
  };
}
