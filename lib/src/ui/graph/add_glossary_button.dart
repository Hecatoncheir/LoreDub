// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/glossary.dart';
import '../../domain/pipeline_graph.dart';
import 'bloc/pipeline_graph_bloc.dart';
import '../theme.dart';

/// Every pack of the glossary, drawn or not: a pack already on the canvas
/// can be drawn again on the other text -- its phrases on what whisper
/// heard, its names and words on what the translator wrote -- and the count
/// beside its name says how many of it are there.
class AddGlossaryButton extends StatelessWidget {
  const AddGlossaryButton({super.key, required this.packs, required this.graph});

  final List<GlossaryPack> packs;
  final PipelineGraph graph;

  Map<String, int> _drawn() {
    final drawn = <String, int>{};
    for (final node in graph.ofKind(PipelineNodeKind.glossary)) {
      drawn.update(node.packId ?? '', (count) => count + 1, ifAbsent: () => 1);
    }
    return drawn;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final drawn = _drawn();
    return PopupMenuButton<String>(
      tooltip: packs.isEmpty ? l10n.pipelineNoGlossaryPacks : l10n.pipelineAddGlossary,
      enabled: packs.isNotEmpty,
      icon: const Icon(Icons.library_add_outlined, size: 20),
      onSelected: (id) => context.read<PipelineGraphBloc>().add(PipelineGlossaryPlaced(id)),
      itemBuilder: (context) => [
        for (final pack in packs)
          PopupMenuItem(
            value: pack.id,
            child: Row(
              children: [
                Expanded(child: Text(pack.name)),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    [
                      l10n.glossaryPackCount(pack.entryKeys.length),
                      if (drawn[pack.id] case final count?) '×$count',
                    ].join('  '),
                    style: context.textStyles.monoCaption,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
