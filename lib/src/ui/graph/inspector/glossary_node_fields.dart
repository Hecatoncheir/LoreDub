// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/pipeline_graph.dart';
import '../../shell/bloc/navigation_cubit.dart';
import '../bloc/pipeline_graph_bloc.dart';
import '../canvas/pipeline_facts.dart';
import 'glossary_pack_picker.dart';
import 'inspector_field.dart';
import 'inspector_note.dart';
import 'inspector_toggle.dart';

/// A pack's panel: which pack the node reads, whether it is switched on,
/// what its place in the line of text lets it put right, and the ways to the
/// glossary's screen and off the canvas.
///
/// Where the node stands is not chosen here: it is the lines drawn into it
/// and out of it, and the same node goes before the translator or after it
/// by where it is drawn.
class GlossaryNodeFields extends StatelessWidget {
  const GlossaryNodeFields({super.key, required this.node, required this.facts});

  final PipelineNode node;
  final PipelineFacts facts;

  /// What the node does where it stands, in a sentence -- on the Screen
  /// page's scheme, about the text read off the screen rather than what
  /// whisper heard.
  String _placeNote(AppLocalizations l10n) {
    final onScreen = node.scheme == PipelineScheme.screen;
    final translates = onScreen ? facts.settings.screenTranslates : facts.settings.translates;
    return switch ((node.feed, node.active)) {
      (null, _) => onScreen ? l10n.pipelineScreenGlossaryOutNote : l10n.pipelineGlossaryOutNote,
      (_, false) => l10n.pipelineGlossaryInactiveNote,
      (GlossaryFeed.recognition, _) => _beforeNote(
        l10n,
        onScreen: onScreen,
        translates: translates,
      ),
      (GlossaryFeed.translation, _) => _afterNote(l10n, onScreen: onScreen, translates: translates),
    };
  }

  /// A pack standing before the translator: its phrases, or -- with nothing
  /// to translate -- its words.
  static String _beforeNote(
    AppLocalizations l10n, {
    required bool onScreen,
    required bool translates,
  }) => switch ((onScreen, translates)) {
    (false, true) => l10n.pipelineGlossaryPhrasesNote,
    (false, false) => l10n.pipelineGlossaryWordsNote,
    (true, true) => l10n.pipelineScreenGlossaryPhrasesNote,
    (true, false) => l10n.pipelineScreenGlossaryWordsNote,
  };

  /// A pack standing after the translator: its names and words, or --
  /// with the translator standing aside -- nothing.
  static String _afterNote(
    AppLocalizations l10n, {
    required bool onScreen,
    required bool translates,
  }) => switch ((onScreen, translates)) {
    (_, true) => l10n.pipelineGlossaryNamesWordsNote,
    (false, false) => l10n.pipelineGlossaryAsideNote,
    (true, false) => l10n.pipelineScreenGlossaryAsideNote,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InspectorField(
          label: l10n.pipelineGlossaryPackLabel,
          child: GlossaryPackPicker(node: node, packs: facts.glossary.packs),
        ),
        // The same switch as the one on the card, and as the glossary
        // screen's: the node stays where it stands either way.
        InspectorToggle(
          label: l10n.pipelineGlossaryActive,
          value: node.active,
          onChanged: (active) => context.read<PipelineGraphBloc>().add(
            PipelineGlossarySwitched(node.id, active: active),
          ),
        ),
        InspectorNote(text: _placeNote(l10n)),
        const SizedBox(height: 6),
        // One under the other, as on a card's panel: side by side in a panel
        // this narrow, both labels were cut.
        OutlinedButton.icon(
          icon: const Icon(Icons.menu_book_rounded, size: 18),
          label: Text(l10n.navGlossary),
          onPressed: () => context.read<NavigationCubit>().selectSection(DashboardSection.glossary),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.close_rounded, size: 18),
          label: Text(l10n.pipelineRemoveNode),
          onPressed: () => context.read<PipelineGraphBloc>().add(PipelineNodeRemoved(node.id)),
        ),
      ],
    );
  }
}
