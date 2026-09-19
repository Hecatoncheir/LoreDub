// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/character.dart';
import '../../../domain/pipeline_graph.dart';
import '../../common/committed_text_field.dart';
import '../../dashboard/cubits/characters_cubit.dart';
import '../../dashboard/cubits/pipeline_graph_bloc.dart';
import '../../dashboard/cubits/shell_cubit.dart';
import '../canvas/pipeline_facts.dart';
import 'inspector_field.dart';
import 'inspector_note.dart';

/// A card's panel: its name, who reads it, what its voice was measured from,
/// and the ways to its screen and off the canvas.
class CharacterNodeFields extends StatelessWidget {
  const CharacterNodeFields({
    super.key,
    required this.node,
    required this.character,
    required this.facts,
    required this.chained,
  });

  final PipelineNode node;
  final Character character;
  final PipelineFacts facts;

  /// Its reader is read by a third, which the substitution does not follow.
  final bool chained;

  static String _gender(AppLocalizations l10n, Character character) => switch (character.gender) {
    'male' => l10n.voiceGenderMale,
    'female' => l10n.voiceGenderFemale,
    _ => l10n.charactersGenderUnknown,
  };

  String _voiceNote(AppLocalizations l10n) => character.vector.isEmpty
      ? l10n.charactersNoVoice
      : l10n.charactersVoiceKept(character.seconds.toStringAsFixed(1), _gender(l10n, character));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final characters = context.read<CharactersCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InspectorField(
          label: l10n.charactersNameLabel,
          child: CommittedTextField(
            // Keyed by the card, so opening another node starts a field on
            // that one's name rather than carrying this one's over.
            key: ValueKey('graph-name-${character.id}'),
            value: character.name,
            onCommitted: (name) => characters.rename(character.id, name),
          ),
        ),
        InspectorField(
          label: l10n.sceneVoiceReadAs,
          child: DropdownButtonFormField<String?>(
            key: ValueKey('graph-reader-${character.id}-${character.voicedBy}'),
            initialValue: character.voicedBy,
            isExpanded: true,
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.charactersOwnVoice)),
              // A card this one already reads is not offered: the panel used
              // to list the whole cast, so two cards could be set to read
              // each other here even though the canvas refuses that line.
              for (final other in readersFor(
                character,
                facts.characters,
                keeping: character.voicedBy,
              ))
                DropdownMenuItem(value: other.id, child: Text(other.name, maxLines: 1)),
            ],
            onChanged: (reader) => characters.voiceAs(character.id, reader),
          ),
        ),
        if (chained) InspectorNote(text: l10n.pipelineChained),
        InspectorNote(text: _voiceNote(l10n)),
        const SizedBox(height: 6),
        // One under the other: side by side in a panel this narrow, both
        // labels were cut — one of them across the middle of a word.
        OutlinedButton.icon(
          icon: const Icon(Icons.groups_rounded, size: 18),
          label: Text(l10n.navCharacters),
          onPressed: () => context.read<ShellCubit>().selectSection(DashboardSection.characters),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.close_rounded, size: 18),
          label: Text(l10n.pipelineRemoveNode),
          onPressed: () => context.read<PipelineGraphBloc>().add(PipelineCharacterRemoved(node.id)),
        ),
      ],
    );
  }
}
