// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/glossary.dart';
import '../../../domain/pipeline_graph.dart';
import '../bloc/pipeline_graph_bloc.dart';

/// The pack a glossary node reads, chosen out of every pack the glossary
/// has, each with how much is in it.
class GlossaryPackPicker extends StatelessWidget {
  const GlossaryPackPicker({super.key, required this.node, required this.packs});

  final PipelineNode node;
  final List<GlossaryPack> packs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final graph = context.read<PipelineGraphBloc>();
    return DropdownButtonFormField<String>(
      // Keyed by the node and its pack, so a pack put back by a step back on
      // the canvas starts a field on that one.
      key: ValueKey('graph-pack-${node.id}-${node.packId}'),
      initialValue: packs.any((pack) => pack.id == node.packId) ? node.packId : null,
      isExpanded: true,
      items: [
        for (final pack in packs)
          DropdownMenuItem(
            value: pack.id,
            child: Text(
              '${pack.name} · ${l10n.glossaryPackCount(pack.entryKeys.length)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (id) {
        if (id != null) graph.add(PipelineGlossaryPackChosen(node.id, id));
      },
    );
  }
}
