// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/pipeline_graph.dart';
import '../../dashboard/cubits/pipeline_graph_bloc.dart';
import '../../theme.dart';
import '../node_paint.dart';

/// The head of the node panel, in the node's own face: its icon, its name
/// under a small "chosen", and the cross that closes the panel.
class NodeInspectorHeader extends StatelessWidget {
  const NodeInspectorHeader({
    super.key,
    required this.node,
    required this.paint,
    required this.title,
  });

  final PipelineNode node;
  final NodePaint paint;
  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: paint.header,
        border: Border(bottom: BorderSide(color: paint.rule)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
      child: Row(
        children: [
          // The node's own icon, as it is drawn in the node's own head.
          Icon(nodeIcon(node.kind), size: 20, color: paint.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.pipelineSelected.toUpperCase(),
                  style: TextStyle(
                    fontFamily: LoreDubFonts.mono,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: paint.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: paint.ink),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.pipelineCloseInspector,
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () =>
                context.read<PipelineGraphBloc>().add(const PipelineNodeSelected(null)),
          ),
        ],
      ),
    );
  }
}
