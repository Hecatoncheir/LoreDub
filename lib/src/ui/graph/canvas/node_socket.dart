// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../domain/pipeline_graph.dart';
import 'node_layer_actions.dart';
import 'port_dot.dart';

/// One socket of a node's layer: the dot, and the box around it that takes
/// hold of a line. Stands in the layer's own stack, [at] being its centre
/// there and [reach] how far its grip goes either way.
class NodeSocket extends StatelessWidget {
  const NodeSocket({
    super.key,
    required this.port,
    required this.at,
    required this.reach,
    required this.filled,
    required this.offered,
    required this.caught,
    required this.actions,
  });

  final PipelinePort port;
  final Offset at;
  final Size reach;
  final bool filled;
  final bool offered;
  final bool caught;
  final NodeLayerActions actions;

  @override
  Widget build(BuildContext context) => Positioned(
    left: at.dx - reach.width,
    top: at.dy - reach.height,
    width: reach.width * 2,
    height: reach.height * 2,
    child: GestureDetector(
      onPanStart: (details) => actions.onLinkStart(port, details.globalPosition),
      onPanUpdate: (details) => actions.onLinkDrag(details.globalPosition),
      onPanEnd: (_) => actions.onLinkEnd(),
      onPanCancel: actions.onLinkEnd,
      child: MouseRegion(
        cursor: SystemMouseCursors.precise,
        child: PortDot(
          signal: port.socket.signal,
          filled: filled,
          offered: offered,
          caught: caught,
        ),
      ),
    ),
  );
}
