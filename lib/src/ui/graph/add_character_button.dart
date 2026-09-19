// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/character.dart';
import '../../domain/pipeline_graph.dart';
import '../dashboard/cubits/pipeline_graph_bloc.dart';
import '../theme.dart';

/// Every card of the cast, drawn or not: a card already on the canvas can
/// be drawn again beside the character whose part it takes over, and the
/// count beside its name says how many of it are there.
class AddCharacterButton extends StatelessWidget {
  const AddCharacterButton({super.key, required this.characters, required this.graph});

  final List<Character> characters;
  final PipelineGraph graph;

  Map<String, int> _drawn() {
    final drawn = <String, int>{};
    for (final node in graph.ofKind(PipelineNodeKind.character)) {
      drawn.update(node.characterId ?? '', (count) => count + 1, ifAbsent: () => 1);
    }
    return drawn;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final drawn = _drawn();
    return PopupMenuButton<String>(
      tooltip: characters.isEmpty ? l10n.pipelineNoCharacters : l10n.pipelineAddCharacter,
      enabled: characters.isNotEmpty,
      icon: const Icon(Icons.person_add_alt_rounded, size: 20),
      onSelected: (id) => context.read<PipelineGraphBloc>().add(PipelineCharacterPlaced(id)),
      itemBuilder: (context) => [
        for (final character in characters)
          PopupMenuItem(
            value: character.id,
            child: Row(
              children: [
                Expanded(child: Text(character.name)),
                if (drawn[character.id] case final count?)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      '×$count',
                      style: const TextStyle(
                        fontFamily: LoreDubFonts.mono,
                        fontSize: 11,
                        color: LoreDubPalette.mutedInk,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
