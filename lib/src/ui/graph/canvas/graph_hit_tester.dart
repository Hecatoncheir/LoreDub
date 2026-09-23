// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math' as math;
import 'dart:ui';

import '../../../domain/character.dart';
import '../../../domain/pipeline_graph.dart';
import 'node_metrics.dart';

/// What lies under the pointer on the canvas: the socket a link is aimed at,
/// the card it is let go on, the cards a band covers. All in canvas places,
/// zoom and pan already taken out; [zoom] only says how far on the canvas the
/// pointer's reach, fixed on the screen, comes to.
class GraphHitTester {
  const GraphHitTester({required this.graph, required this.characters, required this.zoom});

  final PipelineGraph graph;
  final List<Character> characters;
  final double zoom;

  /// The sockets [node] carries, in the order they are declared.
  static Iterable<PipelineSocket> socketsOf(PipelineNode node) => node.sockets;

  /// Whether a link from [from] would be accepted by [port] — what the ring
  /// around a socket shows while the pointer is carrying one.
  bool accepts(PipelinePort from, PipelinePort port) =>
      proposeConnection(graph, from, port, characters: characters) is! RefusedConnection;

  /// The socket a link from [from] let go at [point] should catch.
  ///
  /// The socket aimed at, when one was and it takes the link; otherwise the
  /// first socket of the card let go on that would take it, so a card may be
  /// dropped on anywhere rather than aimed at through a dot. A socket aimed
  /// at that refuses is answered with all the same, since the reason it
  /// gives is worth more than nothing happening.
  PipelinePort? portNear(GraphPoint point, {required PipelinePort from}) {
    final aimed = portAimedAt(point, from: from);
    if (aimed != null && accepts(from, aimed)) return aimed;
    return portOn(point, from: from) ?? aimed;
  }

  /// The socket nearest [point] within the catch radius, [from] aside.
  PipelinePort? portAimedAt(GraphPoint point, {required PipelinePort from}) {
    final at = Offset(point.x, point.y);
    PipelinePort? best;
    var nearest = NodeMetrics.catchRadius / zoom;
    for (final node in graph.nodes) {
      for (final socket in socketsOf(node)) {
        final port = PipelinePort(node.id, socket);
        final distance = (NodeMetrics.portAt(node, socket) - at).distance;
        if (distance > nearest || port == from) continue;
        nearest = distance;
        best = port;
      }
    }
    return best;
  }

  /// The first socket of the card under [point] that would take a link from
  /// [from]. The cards are looked through backwards, the last drawn being
  /// the one on top where two of them overlap.
  PipelinePort? portOn(GraphPoint point, {required PipelinePort from}) {
    final at = Offset(point.x, point.y);
    for (final node in graph.nodes.reversed) {
      if (!NodeMetrics.boundsOf(node).contains(at)) continue;
      for (final socket in socketsOf(node)) {
        final port = PipelinePort(node.id, socket);
        if (port != from && accepts(from, port)) return port;
      }
      return null;
    }
    return null;
  }

  /// Every node [band] covers, by the card it draws rather than by the
  /// corner it starts at: a card half inside the band was meant.
  Set<String> caughtBy(Rect band) => {
    for (final node in graph.nodes)
      if (band.overlaps(NodeMetrics.boundsOf(node))) node.id,
  };

  /// The whole scheme seen at once, in a window of [viewport].
  ///
  /// The canvas works this out rather than the bloc: where a node ends is a
  /// matter of how it is drawn.
  static GraphView fitted(PipelineGraph graph, Size viewport) {
    final spread = NodeMetrics.boundsOfAll(graph.nodes);
    if (spread == null || viewport.isEmpty) return const GraphView(placed: true);
    const margin = 28.0;
    final zoom = math
        .min(
          (viewport.width - margin * 2) / spread.width,
          (viewport.height - margin * 2) / spread.height,
        )
        .clamp(GraphView.smallestZoom, 1.0);
    return GraphView(
      x: (viewport.width - spread.width * zoom) / 2 - spread.left * zoom,
      y: (viewport.height - spread.height * zoom) / 2 - spread.top * zoom,
      zoom: zoom,
      placed: true,
    );
  }
}
