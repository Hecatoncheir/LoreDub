// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/pipeline_graph.dart';
import 'node_layer_actions.dart';
import 'port_dot.dart';
import 'socket_names.dart';

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
    required this.nodeTitle,
    required this.pulling,
  });

  final PipelinePort port;
  final Offset at;
  final Size reach;
  final bool filled;
  final bool offered;
  final bool caught;
  final NodeLayerActions actions;

  /// What the card this socket sits on is called, so a reader hears whose
  /// socket it is rather than a bare "Audio".
  final String nodeTitle;

  /// The socket a line is being drawn from, when one is. It is what this
  /// socket offers to do next: take a line up, put one down, or let go of
  /// the one it started itself.
  final PipelinePort? pulling;

  String _hint(AppLocalizations l10n) {
    if (pulling == null) return l10n.pipelineLinkFrom;
    return pulling == port ? l10n.pipelineLinkDrop : l10n.pipelineLinkTo;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Positioned(
      left: at.dx - reach.width,
      top: at.dy - reach.height,
      width: reach.width * 2,
      height: reach.height * 2,
      // A line is drawn by dragging one dot onto another, which is a
      // gesture neither a keyboard nor a reader has. Named and given an
      // action, those two steps are two activations instead.
      child: Semantics(
        button: true,
        label: l10n.pipelineSocketLabel(nodeTitle, socketName(l10n, port.socket)),
        value: filled ? l10n.pipelineSocketLinked : l10n.pipelineSocketFree,
        hint: _hint(l10n),
        onTap: () => actions.onLinkToggle(port),
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
      ),
    );
  }
}
