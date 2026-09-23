// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/pipeline_graph.dart';
import '../bloc/pipeline_graph_bloc.dart';
import '../canvas/pipeline_facts.dart';
import 'inspector_note.dart';

/// What the lines are read with while no pack of the glossary is switched
/// on, when something is written down: nothing at all once the scheme draws
/// glossaries -- it says what is read then -- and otherwise everything.
/// Nothing is said while a pack is on, or while nothing is written.
class VoiceGlossaryNote extends StatelessWidget {
  const VoiceGlossaryNote({super.key, required this.facts});

  final PipelineFacts facts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final drawn = context.select<PipelineGraphBloc, bool>(
      (graph) => graph.state.graph.ofKind(PipelineNodeKind.glossary).isNotEmpty,
    );
    if (facts.glossary.activePacks.isNotEmpty || facts.glossary.isEmpty) {
      return const SizedBox.shrink();
    }
    return InspectorNote(
      text: drawn ? l10n.pipelineVoiceNoGlossary : l10n.pipelineVoiceWholeGlossary,
    );
  }
}
