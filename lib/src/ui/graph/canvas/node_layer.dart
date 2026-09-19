// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/pipeline_graph.dart';
import 'appearing.dart';
import 'node_card.dart';
import 'node_inputs.dart';
import 'node_labels.dart';
import 'node_metrics.dart';
import 'node_layer_actions.dart';
import 'node_socket.dart';

/// One node on the canvas: its card and the sockets on its edges, drawn
/// from [inputs] and nothing else. That is the whole point of it -- the
/// canvas keeps a layer while its inputs compare equal, so anything a layer
/// read from elsewhere would go on showing what it showed before.
///
/// It stands in the canvas's stack over a box wide enough for the sockets'
/// grip, which reaches past the card's edges.
class NodeLayer extends StatelessWidget {
  const NodeLayer({super.key, required this.inputs, required this.actions});

  final NodeInputs inputs;
  final NodeLayerActions actions;

  /// How far the grip of a socket reaches on either side of it, on the
  /// canvas. The dot shrinks with the canvas; the box that catches the
  /// pointer does not. It is as wide on screen whatever the zoom -- there is
  /// a node's width of empty canvas either side of a socket -- and no taller
  /// than half a row, so that a socket is never covered by the one under it.
  Size get _reach {
    final wide = NodeMetrics.grabReach / inputs.zoom;
    return Size(wide, math.min(wide, NodeMetrics.rowHeight / 2));
  }

  @override
  Widget build(BuildContext context) {
    final node = inputs.node;
    final title = NodeLabels.titleOf(AppLocalizations.of(context), node, inputs.facts);
    final size = NodeMetrics.sizeOf(node.kind);
    final reach = _reach;
    final origin = Offset(node.position.x - reach.width, node.position.y - reach.height);
    return Positioned(
      left: origin.dx,
      top: origin.dy,
      width: size.width + reach.width * 2,
      height: size.height + reach.height * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: reach.width,
            top: reach.height,
            width: size.width,
            height: size.height,
            // A layer of its own: the canvas is panned and zoomed by a
            // transform above every card, and without a boundary under it
            // each of them is painted again on every frame of that.
            child: RepaintBoundary(
              child: Appearing(
                key: ValueKey('rising/${node.id}'),
                child: NodeCard(
                  node: node,
                  facts: inputs.facts,
                  availability: inputs.availability,
                  selected: inputs.selected,
                  onTap: () => actions.onTap(node.id),
                  onGrab: (at) => actions.onGrab(node.id, at),
                  onDrag: (at) => actions.onDrag(node.id, at),
                  onDrop: actions.onDrop,
                  onRemove: node.kind != PipelineNodeKind.character
                      ? null
                      : () => actions.onRemove(node.id),
                ),
              ),
            ),
          ),
          for (final socket in PipelineSocket.values)
            if (socket.owner == node.kind)
              NodeSocket(
                port: PipelinePort(node.id, socket),
                at: NodeMetrics.portAt(node, socket) - origin,
                reach: reach,
                filled: inputs.filled & (1 << socket.index) != 0,
                offered: inputs.offered & (1 << socket.index) != 0,
                caught: inputs.over == PipelinePort(node.id, socket),
                actions: actions,
                nodeTitle: title,
                pulling: inputs.pulling,
              ),
        ],
      ),
    );
  }
}
