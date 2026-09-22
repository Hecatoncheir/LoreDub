// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/pipeline_graph.dart';
import 'package:lore_dub/src/ui/graph/bloc/pipeline_graph_bloc.dart';
import 'package:lore_dub/src/ui/graph/canvas/canvas_gestures.dart';
import 'package:lore_dub/src/ui/graph/canvas/graph_hit_tester.dart';
import 'package:lore_dub/src/ui/graph/canvas/node_metrics.dart';

void main() {
  final graph = buildPipelineGraph(settings: const AppSettings(), characters: const []);
  const recognitionOut = PipelinePort(PipelineNodeIds.recognition, PipelineSocket.speechText);
  const voiceIn = PipelinePort(PipelineNodeIds.voice, PipelineSocket.voiceIn);

  late List<PipelineGraphEvent> told;
  late PipelineGraphState state;
  late int redrawn;
  late CanvasGestures gestures;

  PipelineGraphState at({double zoom = 1, PipelineLinkDrag? drag, Set<String> chosen = const {}}) =>
      PipelineGraphState(
        loading: false,
        graph: graph,
        layout: PipelineLayout(view: GraphView(zoom: zoom)),
        drag: drag,
        chosen: chosen,
      );

  GraphPoint pointOf(PipelinePort port) {
    final at = NodeMetrics.portAt(graph.node(port.nodeId)!, port.socket);
    return GraphPoint(at.dx, at.dy);
  }

  setUp(() {
    told = [];
    state = at();
    redrawn = 0;
    gestures = CanvasGestures(
      add: told.add,
      state: () => state,
      hits: () => GraphHitTester(graph: graph, characters: const [], zoom: state.layout.view.zoom),
    )..addListener(() => redrawn++);
  });

  tearDown(() => gestures.dispose());

  group('a card', () {
    test('moves by as far as the pointer has, at the zoom it is drawn at', () {
      state = at(zoom: 2);

      gestures
        ..grab(PipelineNodeIds.voice, const Offset(100, 100))
        ..carry(PipelineNodeIds.voice, const Offset(120, 90))
        ..carry(PipelineNodeIds.voice, const Offset(130, 90))
        ..drop();

      expect(told.first, isA<PipelineNodeGrabbed>());
      final moves = told.whereType<PipelineNodeMoved>().toList();
      expect([for (final move in moves) (move.dx, move.dy)], [(10.0, -5.0), (5.0, 0.0)]);
      expect(told.last, isA<PipelineArrangementSettled>());
    });

    test('carried without being grabbed first moves nowhere', () {
      gestures.carry(PipelineNodeIds.voice, const Offset(50, 50));

      final move = told.single as PipelineNodeMoved;
      expect((move.dx, move.dy), (0.0, 0.0));
    });

    test('clicked is chosen, with shift added to the choice', () {
      gestures
        ..select(PipelineNodeIds.mix, adding: true)
        ..clearChoice();

      final picked = told.first as PipelineNodeSelected;
      expect(picked.nodeId, PipelineNodeIds.mix);
      expect(picked.add, isTrue);
      expect((told.last as PipelineNodeSelected).nodeId, isNull);
    });

    test('taken off, and a line cut, go to the bloc', () {
      final link = graph.links.first;

      gestures
        ..remove('character:guard')
        ..cut(link);

      expect((told.first as PipelineCharacterRemoved).nodeId, 'character:guard');
      expect((told.last as PipelineLinkCut).link, link);
    });
  });

  group('a pulled line', () {
    test('shows the socket it is over, and is let go onto it', () {
      gestures.pullLink(recognitionOut, pointOf(recognitionOut));
      state = at(
        drag: PipelineLinkDrag(from: recognitionOut, at: pointOf(recognitionOut)),
      );

      gestures.carryLink(pointOf(voiceIn));
      expect(gestures.over, voiceIn);
      expect(redrawn, 1);

      gestures.releaseLink();
      expect((told.last as PipelineLinkReleased).target, voiceIn);
      expect(gestures.over, isNull);
    });

    test('far from any socket is over none, and let go onto nothing', () {
      state = at(
        drag: PipelineLinkDrag(from: recognitionOut, at: pointOf(recognitionOut)),
      );

      gestures
        ..carryLink(const GraphPoint(-500, -500))
        ..releaseLink();

      expect(gestures.over, isNull);
      expect((told.last as PipelineLinkReleased).target, isNull);
      expect(redrawn, 0, reason: 'nothing it draws changed');
    });

    test('drawn from the keyboard is taken up at its socket and put down on another', () {
      gestures.toggleLink(recognitionOut);
      final started = told.single as PipelineLinkStarted;
      expect(started.port, recognitionOut);
      expect(started.at, pointOf(recognitionOut));

      state = at(
        drag: PipelineLinkDrag(from: recognitionOut, at: started.at),
      );
      gestures.toggleLink(voiceIn);
      expect((told.last as PipelineLinkReleased).target, voiceIn);

      gestures.toggleLink(recognitionOut);
      expect(
        (told.last as PipelineLinkReleased).target,
        isNull,
        reason: 'its own socket lets it go',
      );
    });

    test('from a card no longer on the scheme is not taken up', () {
      gestures.toggleLink(const PipelinePort('character:gone', PipelineSocket.characterIn));

      expect(told, isEmpty);
    });
  });

  group('empty space', () {
    test('pans the canvas, and settles when let go', () {
      gestures
        ..pressSpace(const GraphPoint(0, 0), banding: false)
        ..dragSpace(const Offset(12, -4), const GraphPoint(12, -4))
        ..releaseSpace(adding: false);

      final pan = told.first as PipelineViewPanned;
      expect((pan.dx, pan.dy), (12.0, -4.0));
      expect(told.last, isA<PipelineArrangementSettled>());
      expect(gestures.band, isNull);
    });

    test('with control held draws a band, and chooses what it caught', () {
      final card = NodeMetrics.boundsOf(graph.node(PipelineNodeIds.mix)!);

      gestures
        ..pressSpace(GraphPoint(card.right + 10, card.bottom + 10), banding: true)
        ..dragSpace(Offset.zero, GraphPoint(card.left - 10, card.top - 10));
      expect(
        gestures.band,
        Rect.fromLTRB(card.left - 10, card.top - 10, card.right + 10, card.bottom + 10),
      );

      gestures.releaseSpace(adding: false);

      expect((told.single as PipelineSelectionSet).nodeIds, contains(PipelineNodeIds.mix));
      expect(gestures.band, isNull);
      expect(redrawn, 3, reason: 'pressed, drawn and let go');
    });

    test('a band drawn with shift adds to what was chosen', () {
      state = at(chosen: {PipelineNodeIds.source});

      gestures
        ..pressSpace(const GraphPoint(-900, -900), banding: true)
        ..dragSpace(Offset.zero, const GraphPoint(-800, -800))
        ..releaseSpace(adding: true);

      expect((told.single as PipelineSelectionSet).nodeIds, {PipelineNodeIds.source});
    });
  });

  test('the wheel zooms a tenth out for a turn down and in for a turn up', () {
    state = at(zoom: 2);

    gestures
      ..wheel(40, const GraphPoint(5, 5))
      ..wheel(-40, const GraphPoint(5, 5));

    final zooms = told.whereType<PipelineViewZoomed>().toList();
    expect(zooms.first.zoom, closeTo(1.8, 1e-9));
    expect(zooms.last.zoom, closeTo(2.2, 1e-9));
    expect(zooms.first.focus, const GraphPoint(5, 5));
  });
}
