// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../domain/pipeline_graph.dart';
import '../../dashboard/cubits/pipeline_graph_bloc.dart';
import 'graph_hit_tester.dart';
import 'node_metrics.dart';

/// What the pointer does on the scheme, turned into what the bloc is told.
///
/// A gesture here is a sequence -- grab, move, drop; pull a line, carry it,
/// let it go; press on empty space and draw a band or pan -- and the little
/// it has to remember between its steps lives here rather than in the
/// canvas's state beside the animations: where a card was last held, which
/// socket a pulled line is over, the band's corners. The canvas turns the
/// pointer into places and draws what it is told; what a place means is
/// answered here, and a change the canvas draws is a [notifyListeners].
///
/// Modifier keys are handed in with each step rather than read here, so a
/// test can press them without a keyboard.
class CanvasGestures extends ChangeNotifier {
  CanvasGestures({required this.add, required this.state, required this.hits});

  /// Where every step's answer goes: the bloc's own `add`.
  final void Function(PipelineGraphEvent event) add;

  /// The scheme as it stands, asked afresh at every step.
  final PipelineGraphState Function() state;

  /// What lies where, on that scheme at its zoom.
  final GraphHitTester Function() hits;

  PipelinePort? _over;

  /// The socket a pulled line is over, drawn as the one that would catch
  /// it.
  PipelinePort? get over => _over;

  /// Where the pointer was when a card last answered it, on the screen.
  /// What the card moves is the distance from here, so it keeps up with the
  /// pointer exactly instead of with its own idea of how far it has come.
  Offset? _held;

  GraphPoint? _bandFrom;
  GraphPoint? _bandTo;

  /// The band drawn over empty space with control held, corners in order,
  /// or null while none is.
  Rect? get band {
    final from = _bandFrom;
    final to = _bandTo;
    if (from == null || to == null) return null;
    return Rect.fromLTRB(
      math.min(from.x, to.x),
      math.min(from.y, to.y),
      math.max(from.x, to.x),
      math.max(from.y, to.y),
    );
  }

  double get _zoom => state().layout.view.zoom;

  void _hover(PipelinePort? port) {
    if (port == _over) return;
    _over = port;
    notifyListeners();
  }

  /// A card clicked; with [adding] it joins what is chosen.
  void select(String nodeId, {required bool adding}) =>
      add(PipelineNodeSelected(nodeId, add: adding));

  /// Empty space clicked: nothing is chosen.
  void clearChoice() => add(const PipelineNodeSelected(null));

  void grab(String nodeId, Offset at) {
    _held = at;
    add(PipelineNodeGrabbed(nodeId));
  }

  void carry(String nodeId, Offset at) {
    final from = _held ?? at;
    _held = at;
    add(PipelineNodeMoved(nodeId, (at.dx - from.dx) / _zoom, (at.dy - from.dy) / _zoom));
  }

  void drop() {
    _held = null;
    add(const PipelineArrangementSettled());
  }

  void remove(String nodeId) => add(PipelineCharacterRemoved(nodeId));

  void cut(PipelineLink link) => add(PipelineLinkCut(link));

  void pullLink(PipelinePort port, GraphPoint at) {
    _hover(null);
    add(PipelineLinkStarted(port, at));
  }

  void carryLink(GraphPoint at) {
    final from = state().drag?.from;
    _hover(from == null ? null : hits().portNear(at, from: from));
    add(PipelineLinkDragged(at));
  }

  void releaseLink() {
    add(PipelineLinkReleased(_over));
    _hover(null);
  }

  /// A line drawn without a pointer: the first socket takes it up, the
  /// second puts it down, and the one it started from lets it go. It goes
  /// through the same events a drag does, so what a link may join and what
  /// it changes is answered in one place.
  void toggleLink(PipelinePort port) {
    final now = state();
    final drag = now.drag;
    if (drag == null) {
      final node = now.graph.node(port.nodeId);
      if (node == null) return;
      final at = NodeMetrics.portAt(node, port.socket);
      add(PipelineLinkStarted(port, GraphPoint(at.dx, at.dy)));
      return;
    }
    add(PipelineLinkReleased(drag.from == port ? null : port));
    _hover(null);
  }

  /// A press on empty space: with [banding] -- control held -- it draws a
  /// band over the cards, which is the one gesture that needs a modifier to
  /// tell it from panning.
  void pressSpace(GraphPoint at, {required bool banding}) {
    if (!banding) return;
    _bandFrom = at;
    _bandTo = at;
    notifyListeners();
  }

  /// The press moves: the band follows [at], or the canvas pans by [delta].
  void dragSpace(Offset delta, GraphPoint at) {
    if (_bandFrom == null) {
      add(PipelineViewPanned(delta.dx, delta.dy));
      return;
    }
    _bandTo = at;
    notifyListeners();
  }

  /// The press is let go. A band drawn with [adding] -- shift held -- adds
  /// what it caught to what was chosen; on its own it is the whole choice.
  void releaseSpace({required bool adding}) {
    final drawn = band;
    if (drawn == null) {
      add(const PipelineArrangementSettled());
      return;
    }
    final caught = hits().caughtBy(drawn);
    add(PipelineSelectionSet(adding ? {...state().chosen, ...caught} : caught));
    _bandFrom = null;
    _bandTo = null;
    notifyListeners();
  }

  /// The wheel zooms about [about], a place in the window: a tenth nearer
  /// for a turn towards the player, a tenth further for one away.
  void wheel(double scrolled, GraphPoint about) =>
      add(PipelineViewZoomed(_zoom * (scrolled > 0 ? 0.9 : 1.1), about));
}
