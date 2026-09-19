// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../domain/pipeline_graph.dart';
import '../../dashboard/cubits/pipeline_graph_bloc.dart';
import '../../theme.dart';
import 'link_geometry.dart';
import 'node_metrics.dart';

/// The curves. The route is a solid orange line and the cast is dashed, so
/// what is signal and what is casting are told apart without reading a
/// label. Among the dashed ones, the voice a card sends to the mix is orange
/// as well -- that one is heard, and it ends in the orange path out -- while
/// the lines among the cards themselves stay graphite.
class LinkPainter extends CustomPainter {
  // Repainted by the animation rather than rebuilt with it: a builder
  // ticking every frame hands the whole layer a new widget, and the layer
  // holds every line of the scheme.
  LinkPainter({
    required this.graph,
    required this.grown,
    this.drag,
    this.over,
    this.appearing = const {},
    this.fading = const {},
    this.leaving = const [],
  }) : super(repaint: grown);

  final PipelineGraph graph;
  final PipelineLinkDrag? drag;
  final PipelinePort? over;

  /// The lines just drawn, which grow out of the socket they leave, and the
  /// ones just cut, which fade where they lay. [grown] is how far along both
  /// of those are; [leaving] holds the cards a cut line still hangs off.
  final Set<PipelineLink> appearing;
  final Set<PipelineLink> fading;
  final List<PipelineNode> leaving;
  final Animation<double> grown;

  /// The node [id] is drawn as, whether it is still on the canvas or on its
  /// way off it: a line being cut with the card it hung off has to be drawn
  /// somewhere while it fades.
  PipelineNode? _nodeOf(String id) {
    if (graph.node(id) case final node?) return node;
    for (final node in leaving) {
      if (node.id == id) return node;
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final link in [...graph.links, ...fading]) {
      _paintLink(canvas, link);
    }
    _paintPulled(canvas);
  }

  void _paintLink(Canvas canvas, PipelineLink link) {
    final from = _nodeOf(link.from.nodeId);
    final to = _nodeOf(link.to.nodeId);
    if (from == null || to == null) return;
    final path = LinkGeometry.pathBetween(
      NodeMetrics.portAt(from, link.from.socket),
      NodeMetrics.portAt(to, link.to.socket),
    );
    final cast = link.signal == PipelineSignal.voice;
    // A line just drawn runs out of the socket it leaves and reaches for the
    // one it was dropped on; a line just cut fades where it lay. Which of the
    // two happened is worth seeing without reading the whole scheme again.
    final drawn = appearing.contains(link) ? LinkGeometry.upTo(path, grown.value) : path;
    final alpha = fading.contains(link) ? (1 - grown.value).clamp(0.0, 1.0) : 1.0;
    canvas.drawPath(
      cast ? LinkGeometry.dashed(drawn) : drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cast ? 1.6 : 2.4
        ..strokeCap = StrokeCap.round
        ..color = _colourOf(link).withValues(alpha: alpha),
    );
  }

  /// A voice going into the mix is the one the player hears, so it carries
  /// the orange of the path it joins; the casting among the cards is
  /// graphite, being an arrangement rather than a signal.
  static Color _colourOf(PipelineLink link) {
    final cast = link.signal == PipelineSignal.voice;
    final heard = link.to.socket == PipelineSocket.mixCast;
    return cast && !heard ? LoreDubPalette.graphite : LoreDubPalette.orange;
  }

  /// The link the pointer is carrying, dashed, orange once a socket would
  /// catch it.
  void _paintPulled(Canvas canvas) {
    final pulling = drag;
    if (pulling == null) return;
    final node = graph.node(pulling.from.nodeId);
    if (node == null) return;
    final from = NodeMetrics.portAt(node, pulling.from.socket);
    final to = Offset(pulling.at.x, pulling.at.y);
    final path = pulling.from.isOutput
        ? LinkGeometry.pathBetween(from, to)
        : LinkGeometry.pathBetween(to, from);
    canvas.drawPath(
      LinkGeometry.dashed(path),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = over == null ? LoreDubPalette.mutedInk : LoreDubPalette.orange,
    );
  }

  @override
  bool shouldRepaint(LinkPainter old) =>
      old.graph != graph ||
      old.drag != drag ||
      old.over != over ||
      old.appearing != appearing ||
      old.fading != fading;
}
