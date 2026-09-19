// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../common/ease.dart';

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/pipeline_graph.dart';
import '../../theme.dart';
import '../node_paint.dart';
import 'node_metrics.dart';

/// The head of a node card: its icon and name, the cross that takes a card
/// of the cast off the canvas, and the word for a stage the route no longer
/// reaches.
class NodeCardHeader extends StatelessWidget {
  const NodeCardHeader({
    super.key,
    required this.node,
    required this.paint,
    required this.title,
    required this.onRemove,
  });

  final PipelineNode node;
  final NodePaint paint;
  final String title;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnimatedContainer(
      duration: ease(context),
      curve: Curves.easeOut,
      height: NodeMetrics.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: paint.header,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
        border: Border(bottom: BorderSide(color: paint.rule)),
      ),
      child: Row(
        children: [
          Icon(nodeIcon(node.kind), size: 18, color: paint.ink),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: paint.ink),
            ),
          ),
          if (onRemove case final remove?)
            // On the card itself rather than only in the panel: a card is put
            // on the canvas by hand and taken off the same way.
            SizedBox(
              width: 26,
              height: 26,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 16,
                tooltip: l10n.pipelineRemoveNode,
                color: paint.muted,
                icon: const Icon(Icons.close_rounded),
                onPressed: remove,
              ),
            ),
          if (node.unrouted)
            Text(
              l10n.pipelineUnrouted.toUpperCase(),
              style: TextStyle(
                fontFamily: LoreDubFonts.mono,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: paint.muted,
              ),
            ),
        ],
      ),
    );
  }
}
