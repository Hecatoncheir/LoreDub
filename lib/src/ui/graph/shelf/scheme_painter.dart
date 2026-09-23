// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/app_settings.dart';
import '../../../domain/character.dart';
import '../../../domain/glossary.dart';
import '../../../domain/pipeline_graph.dart';
import '../../../domain/saved_pipeline.dart';
import '../../theme.dart';
import '../canvas/node_metrics.dart';

/// The scheme at the size of a thumbnail: every node a box where it stands,
/// every link a line between them, fitted into whatever room the card has.
///
/// Handed the scheme rather than its graph, and building the graph only when
/// it paints: a graph built in the card's `build` is a new one every time,
/// and a graph is told apart from another by identity, so the thumbnail was
/// painted again on every rebuild of the shelf.
class SchemePainter extends CustomPainter {
  SchemePainter({
    required this.scheme,
    required this.cast,
    required this.colors,
    this.packs = const [],
  });

  final SavedPipeline scheme;

  /// The roles the thumbnail is drawn in. A painter stands outside the
  /// widget tree and has no context to read them off.
  final LoreDubColors colors;

  /// The cards the machine has, so the picture draws the characters the
  /// scheme names rather than boxes with nothing in them.
  final List<Character> cast;

  /// The packs the glossary has, likewise -- each switched as the scheme
  /// switches it, so the picture shows the lines the scheme puts up rather
  /// than the ones the canvas has now.
  final List<GlossaryPack> packs;

  late final PipelineGraph graph = buildPipelineGraph(
    // Whether the game's sound is drawn in, which is a setting of its own
    // on each of the two canvases.
    settings: switch (scheme.scheme) {
      PipelineScheme.live => AppSettings(captureRouted: scheme.captureRouted),
      PipelineScheme.screen => AppSettings(screenVoices: scheme.captureRouted),
    },
    scheme: scheme.scheme,
    characters: cast,
    packs: switch (scheme.activePacks) {
      final active? => [
        for (final pack in packs) pack.copyWith(active: active.contains(pack.id)),
      ],
      null => packs,
    },
    layout: scheme.layout,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final spread = NodeMetrics.boundsOfAll(graph.nodes);
    if (spread == null || spread.width <= 0 || spread.height <= 0) return;

    // As large as fits either way, and put in the middle of what room there
    // is, so a wide scheme and a tall one both sit in the card rather than
    // hugging a corner of it.
    final scale = math.min(size.width / spread.width, size.height / spread.height);
    final offset = Offset(
      (size.width - spread.width * scale) / 2,
      (size.height - spread.height * scale) / 2,
    );
    Offset place(GraphPoint point) => Offset(
      (point.x - spread.left) * scale + offset.dx,
      (point.y - spread.top) * scale + offset.dy,
    );

    _drawWires(canvas, place);
    _drawCards(canvas, place);
  }

  /// The links, as straight lines rather than the canvas's curves: at a
  /// thumb's width a curve and a line look the same.
  void _drawWires(Canvas canvas, Offset Function(GraphPoint point) place) {
    final wire = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = colors.mutedInk;
    for (final link in graph.links) {
      final from = graph.node(link.from.nodeId);
      final to = graph.node(link.to.nodeId);
      if (from == null || to == null) continue;
      final start = NodeMetrics.portAt(from, link.from.socket);
      final end = NodeMetrics.portAt(to, link.to.socket);
      canvas.drawLine(
        place(GraphPoint(start.dx, start.dy)),
        place(GraphPoint(end.dx, end.dy)),
        wire..color = link.signal == PipelineSignal.voice ? colors.mutedInk : colors.accent,
      );
    }
  }

  /// The nodes, as filled boxes with an edge: a card of the player's cast
  /// lighter than a stage, and anything unrouted drawn dark.
  void _drawCards(Canvas canvas, Offset Function(GraphPoint point) place) {
    for (final node in graph.nodes) {
      final card = NodeMetrics.sizeOf(node.kind);
      final box = Rect.fromPoints(
        place(node.position),
        place(node.position.translate(card.width, card.height)),
      );
      final rounded = RRect.fromRectAndRadius(box, const Radius.circular(2));
      canvas.drawRRect(
        rounded,
        Paint()
          ..color = !node.unrouted && node.kind == PipelineNodeKind.character
              ? colors.panel
              : colors.raised,
      );
      canvas.drawRRect(
        rounded,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = node.unrouted ? colors.outline : colors.ink,
      );
    }
  }

  @override
  bool shouldRepaint(SchemePainter old) =>
      old.scheme != scheme || old.cast != cast || old.packs != packs || old.colors != colors;
}
