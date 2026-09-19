// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/pipeline_graph.dart';
import 'package:lore_dub/src/ui/graph/canvas/dot_field.dart';
import 'package:lore_dub/src/ui/graph/canvas/graph_hit_tester.dart';
import 'package:lore_dub/src/ui/graph/canvas/link_cut.dart';
import 'package:lore_dub/src/ui/graph/canvas/link_geometry.dart';
import 'package:lore_dub/src/ui/graph/canvas/node_metrics.dart';
import 'package:lore_dub/src/ui/graph/canvas/scheme_diff.dart';

void main() {
  final graph = buildPipelineGraph(settings: const AppSettings(), characters: const []);
  PipelineNode node(String id) => graph.node(id)!;
  const recognitionIn = PipelinePort(PipelineNodeIds.recognition, PipelineSocket.speechIn);
  const sourceOut = PipelinePort(PipelineNodeIds.source, PipelineSocket.gameAudio);

  group('hit testing', () {
    final hits = GraphHitTester(graph: graph, characters: const [], zoom: 1);
    GraphPoint at(Offset offset) => GraphPoint(offset.dx, offset.dy);

    test('catches the socket a link is let go near', () {
      final socket = NodeMetrics.portAt(node(PipelineNodeIds.voice), PipelineSocket.voiceIn);
      const from = PipelinePort(PipelineNodeIds.recognition, PipelineSocket.speechText);

      expect(
        hits.portAimedAt(at(socket + const Offset(10, 5)), from: from),
        const PipelinePort(PipelineNodeIds.voice, PipelineSocket.voiceIn),
      );
      expect(hits.portAimedAt(at(socket + const Offset(200, 200)), from: from), isNull);
    });

    test('reaches further on the canvas the smaller it is drawn', () {
      final socket = NodeMetrics.portAt(node(PipelineNodeIds.recognition), PipelineSocket.speechIn);
      final far = at(socket + const Offset(60, 0));
      final small = GraphHitTester(graph: graph, characters: const [], zoom: 0.5);

      expect(hits.portAimedAt(far, from: sourceOut), isNull);
      expect(small.portAimedAt(far, from: sourceOut), recognitionIn);
    });

    test('takes a link let go anywhere on a card that has a socket for it', () {
      final middle = NodeMetrics.boundsOf(node(PipelineNodeIds.recognition)).center;

      expect(hits.portOn(at(middle), from: sourceOut), recognitionIn);
    });

    test('catches the cards a band covers, a card half inside it too', () {
      final card = NodeMetrics.boundsOf(node(PipelineNodeIds.mix));
      final band = Rect.fromLTWH(card.left - 20, card.top - 20, card.width / 2, 40);

      expect(hits.caughtBy(band), contains(PipelineNodeIds.mix));
    });

    test('fits the whole scheme into a window, inside its margin', () {
      const window = Size(800, 600);
      final view = GraphHitTester.fitted(graph, window);
      final spread = NodeMetrics.boundsOfAll(graph.nodes)!;

      expect(view.placed, isTrue);
      expect(view.x + spread.left * view.zoom, greaterThanOrEqualTo(27.9));
      expect(view.x + spread.right * view.zoom, lessThanOrEqualTo(800 - 27.9));
      expect(GraphHitTester.fitted(const PipelineGraph(), window).zoom, 1);
    });
  });

  test('tells what an edit drew, cut, took off and put on', () {
    final linked = PipelineGraph(nodes: graph.nodes, links: graph.links.skip(1).toList());
    final diff = SchemeDiff.between(linked, graph);

    expect(diff.appearing, {graph.links.first});
    expect(diff.fading, isEmpty);
    expect(SchemeDiff.between(graph, graph).isEmpty, isTrue);
    final without = PipelineGraph(nodes: graph.nodes.skip(1).toList(), links: graph.links);
    expect(SchemeDiff.between(graph, without).leaving.single, graph.nodes.first);
    expect(SchemeDiff.between(without, graph).arriving, {graph.nodes.first.id});
  });

  test('gives a cut badge only to the lines that mean something', () {
    const route = PipelineLink(sourceOut, recognitionIn);
    const mixOut = PipelineLink(
      PipelinePort(PipelineNodeIds.mix, PipelineSocket.mixOut),
      PipelinePort(PipelineNodeIds.output, PipelineSocket.streamIn),
    );

    expect(LinkCut.of(route), LinkCut.route);
    expect(LinkCut.of(mixOut), isNull);
  });

  test('sets a badge on the middle of its curve', () {
    const from = Offset(0, 0);
    const to = Offset(400, 100);
    final middle = LinkGeometry.middleOf(from, to);
    final metric = LinkGeometry.pathBetween(from, to).computeMetrics().single;
    final halfway = metric.getTangentForOffset(metric.length / 2)!.position;

    expect(middle.dy, closeTo(50, 0.001));
    expect((middle - halfway).distance, lessThan(12));
  });

  group('field of dots', () {
    final field = DotField(18);
    const card = FieldCard(rect: Rect.fromLTWH(100, 100, 200, 100), strength: 1, chosen: false);

    test('draws no dot under a card', () {
      expect(field.place(const Offset(150, 150), [card]), isNull);
    });

    test('pushes a dot near a card away from it', () {
      final dot = field.place(const Offset(320, 150), [card])!;

      expect(dot.at.dx, greaterThan(320));
      expect(dot.at.dy, closeTo(150, 0.001));
    });

    test('lights a dot near a chosen card and leaves one far away as it was', () {
      const chosen = FieldCard(rect: Rect.fromLTWH(100, 100, 200, 100), strength: 1, chosen: true);

      expect(field.place(const Offset(340, 150), [chosen])!.shade, greaterThan(0));
      final far = field.place(const Offset(900, 900), [card])!;
      expect(far.at, const Offset(900, 900));
      expect(far.left, DotField.steps);
    });
  });
}
