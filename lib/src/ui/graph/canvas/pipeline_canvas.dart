// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/compute_device.dart';
import '../../../domain/pipeline_graph.dart';
import '../../theme.dart';
import '../../dashboard/cubits/pipeline_graph_bloc.dart';
import 'node_metrics.dart';
import 'pipeline_facts.dart';
import 'graph_hit_tester.dart';
import 'link_cut.dart';
import 'link_cut_badge.dart';
import 'link_geometry.dart';
import 'scheme_diff.dart';
import 'dot_field_painter.dart';
import 'link_painter.dart';
import 'port_dot.dart';
import 'appearing.dart';
import 'node_card.dart';
import 'node_inputs.dart';

/// The scheme: a dotted field the nodes sit on, the links between them, and
/// the link the pointer is carrying.
class PipelineCanvas extends StatefulWidget {
  const PipelineCanvas({
    super.key,
    required this.bloc,
    required this.state,
    required this.facts,
    required this.availability,
  });

  final PipelineGraphBloc bloc;
  final PipelineGraphState state;
  final PipelineFacts facts;
  final ComputeAvailability availability;

  @override
  State<PipelineCanvas> createState() => _PipelineCanvasState();
}

class _PipelineCanvasState extends State<PipelineCanvas> with SingleTickerProviderStateMixin {
  /// How long a line takes to draw itself in, and a line or a card to go.
  /// Long enough to be seen following the pointer that drew it, short enough
  /// that nobody waits for it.
  static const _motion = Duration(milliseconds: 280);

  /// Runs whenever the scheme gains or loses something. One controller for
  /// the lot: everything a single edit changes moves together, which is what
  /// makes it read as one change rather than as several.
  late final AnimationController _drawing = AnimationController(vsync: this, duration: _motion)
    ..addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      setState(() {
        _appearing = const {};
        _fading = const {};
        _leaving = const [];
        _arriving = const {};
      });
    });

  late final Animation<double> _grown = CurvedAnimation(
    parent: _drawing,
    curve: Curves.easeOutCubic,
  );

  /// A card on its way off: it fades and draws in a little as it goes.
  late final Animation<double> _going = Tween<double>(begin: 1, end: 0).animate(_grown);
  late final Animation<double> _shrinking = Tween<double>(begin: 1, end: 0.96).animate(_grown);

  /// The lines drawn since the last frame, which grow from their socket, and
  /// the ones taken away, which fade where they were.
  Set<PipelineLink> _appearing = const {};
  Set<PipelineLink> _fading = const {};

  /// The cards taken off the canvas, kept until they have faded out, and
  /// the ones just put on it — the field of dots parts for a card as it
  /// arrives and closes again behind one that goes.
  List<PipelineNode> _leaving = const [];
  Set<String> _arriving = const {};

  /// What each node's layer — its card and its sockets — was last drawn
  /// from, and what came out. A dragged node hands the canvas a whole new
  /// graph on every frame and a pan hands it a new state: without this,
  /// thirty cards and ninety sockets were built again for one of them
  /// moving, and for a pan that moved none of them at all.
  final _drawn = <String, ({NodeInputs from, List<Widget> layer})>{};

  /// The badge on each line and where it sat when it was made. A badge
  /// rides the middle of its curve, so it is the same badge until one of the
  /// two cards it runs between moves.
  var _badges = <PipelineLink, ({Offset at, Widget badge})>{};

  final _viewport = GlobalKey();

  /// The port the pointer is over while a link is being pulled, so it can
  /// be shown as the one that would catch it.
  PipelinePort? _over;

  /// Where the pointer was when a node last answered it, on the screen. What
  /// a node moves is the distance from here, so it keeps up with the pointer
  /// exactly instead of with its own idea of how far it has come.
  Offset? _dragging;

  @override
  void initState() {
    super.initState();
    // The scheme draws itself when the screen is opened, line by line out of
    // the sockets they leave.
    _appearing = widget.state.graph.links.toSet();
    if (_appearing.isNotEmpty) _drawing.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A player who has turned animation off in Windows is shown the end of
    // every one of these at once.
    _drawing.duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : _motion;
    // What is kept was built against the language and the theme that were
    // around it, so a change of either throws all of it away.
    _drawn.clear();
    _badges = {};
  }

  @override
  void didUpdateWidget(PipelineCanvas old) {
    super.didUpdateWidget(old);
    final diff = SchemeDiff.between(old.state.graph, widget.state.graph);
    if (diff.isEmpty) return;
    _appearing = diff.appearing;
    _fading = diff.fading;
    _leaving = diff.leaving;
    _arriving = diff.arriving;
    _drawing.forward(from: 0);
  }

  @override
  void dispose() {
    _drawing.dispose();
    super.dispose();
  }

  /// The band being drawn with control held, in canvas places. Null while
  /// no band is being drawn, which is most of the time.
  GraphPoint? _bandFrom;
  GraphPoint? _bandTo;

  /// Whether the modifier is down right now. Read at the moment of the
  /// gesture rather than kept: a key let go while the pointer is down must
  /// not turn a band into a pan half way through.
  static bool get _adding => HardwareKeyboard.instance.isShiftPressed;
  static bool get _banding =>
      HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;

  /// The band as it stands, with its corners put in order.
  Rect? get _band {
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

  PipelineGraphState get _state => widget.state;
  GraphView get _view => _state.layout.view;

  /// What lies under the pointer, on the graph as it stands this frame.
  GraphHitTester get _hits => GraphHitTester(
    graph: _state.graph,
    characters: widget.facts.characters,
    zoom: _view.zoom,
  );

  /// [global] as a place on the canvas, zoom and pan taken out.
  GraphPoint _toCanvas(Offset global) {
    final box = _viewport.currentContext?.findRenderObject() as RenderBox?;
    final local = box?.globalToLocal(global) ?? global;
    return _view.toCanvas(GraphPoint(local.dx, local.dy));
  }

  void _startLink(PipelinePort port, Offset global) {
    setState(() => _over = null);
    widget.bloc.add(PipelineLinkStarted(port, _toCanvas(global)));
  }

  void _dragLink(Offset global) {
    final at = _toCanvas(global);
    final from = _state.drag?.from;
    final over = from == null ? null : _hits.portNear(at, from: from);
    if (over != _over) setState(() => _over = over);
    widget.bloc.add(PipelineLinkDragged(at));
  }

  void _endLink() {
    widget.bloc.add(PipelineLinkReleased(_over));
    setState(() => _over = null);
  }

  @override
  Widget build(BuildContext context) {
    final view = _view;
    return LayoutBuilder(
      builder: (context, constraints) {
        // A scheme that has never been fitted into the window is put there
        // once, after the frame that measured it.
        if (!view.placed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_view.placed) {
              widget.bloc.add(
                PipelineViewSet(GraphHitTester.fitted(_state.graph, constraints.biggest)),
              );
            }
          });
        }
        return _canvas(context, view);
      },
    );
  }

  /// The wheel zooms the canvas about the point under the pointer.
  void _zoom(PointerSignalEvent signal) {
    if (signal is! PointerScrollEvent) return;
    final box = _viewport.currentContext?.findRenderObject() as RenderBox?;
    final local = box?.globalToLocal(signal.position) ?? signal.position;
    widget.bloc.add(
      PipelineViewZoomed(
        _view.zoom * (signal.scrollDelta.dy > 0 ? 0.9 : 1.1),
        GraphPoint(local.dx, local.dy),
      ),
    );
  }

  void _startPan(DragStartDetails details) {
    if (!_banding) return;
    setState(() {
      _bandFrom = _toCanvas(details.globalPosition);
      _bandTo = _bandFrom;
    });
  }

  void _pan(DragUpdateDetails details) {
    if (_bandFrom == null) {
      widget.bloc.add(PipelineViewPanned(details.delta.dx, details.delta.dy));
      return;
    }
    setState(() => _bandTo = _toCanvas(details.globalPosition));
  }

  void _endPan() {
    final band = _band;
    if (band == null) {
      widget.bloc.add(const PipelineArrangementSettled());
      return;
    }
    // A band drawn with shift held adds to what was chosen; on its own it
    // is the whole choice.
    final caught = _hits.caughtBy(band);
    widget.bloc.add(PipelineSelectionSet(_adding ? {..._state.chosen, ...caught} : caught));
    setState(() {
      _bandFrom = null;
      _bandTo = null;
    });
  }

  Widget _canvas(BuildContext context, GraphView view) {
    final filled = _filledSockets();
    // Only the cards still drawn are worth remembering.
    final drawn = {for (final node in _state.graph.nodes) node.id};
    _drawn.removeWhere((id, _) => !drawn.contains(id));
    return ClipRect(
      child: Listener(
        key: _viewport,
        onPointerSignal: _zoom,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.bloc.add(const PipelineNodeSelected(null)),
          // Empty space drags the canvas, as it always has; with control
          // held it draws a band over the nodes instead, which is the one
          // gesture that needs a modifier to tell it from panning.
          onPanStart: _startPan,
          onPanUpdate: _pan,
          onPanEnd: (_) => _endPan(),
          child: CustomPaint(
            painter: DotFieldPainter(
              view: view,
              // The cards on their way off still part the field, less and
              // less of it, so it closes behind them rather than snapping
              // shut.
              nodes: [..._state.graph.nodes, ..._leaving],
              chosen: _state.chosen,
              arriving: _arriving,
              leaving: {for (final node in _leaving) node.id},
              grown: _grown,
            ),
            // The nodes sit on a box of their own rather than on the window:
            // a child drawn outside its parent is painted but not hit, and
            // the far end of the pipeline could be seen, dragged, and never
            // clicked. The overflow box is what lets that box be bigger than
            // the window; it keeps the window's own size, so every point the
            // player can see still reaches through it.
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: 0,
              minHeight: 0,
              maxWidth: GraphWorld.width,
              maxHeight: GraphWorld.height,
              child: Transform(
                alignment: Alignment.topLeft,
                transform: Matrix4.identity()
                  ..translateByDouble(view.x, view.y, 0, 1)
                  ..scaleByDouble(view.zoom, view.zoom, 1, 1),
                child: SizedBox(
                  width: GraphWorld.width,
                  height: GraphWorld.height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: LinkPainter(
                            graph: _state.graph,
                            drag: _state.drag,
                            over: _over,
                            appearing: _appearing,
                            fading: _fading,
                            leaving: _leaving,
                            grown: _grown,
                          ),
                        ),
                      ),
                      // The cards that have been taken off go under the ones
                      // that are still here, and answer to nothing while
                      // they fade.
                      for (final node in _leaving) ..._leavingLayer(context, node),
                      for (final node in _state.graph.nodes) ..._nodeLayer(context, node, filled),
                      ..._cutButtons(),
                      if (_band case final band?)
                        Positioned.fromRect(
                          rect: band,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: LoreDubPalette.orange.withValues(alpha: 0.08),
                                border: Border.all(color: LoreDubPalette.orange),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A card on its way off the canvas: where it was, fading, and deaf.
  List<Widget> _leavingLayer(BuildContext context, PipelineNode node) {
    final size = NodeMetrics.sizeOf(node.kind);
    return [
      Positioned(
        key: ValueKey('leaving/${node.id}'),
        left: node.position.x,
        top: node.position.y,
        width: size.width,
        height: size.height,
        child: IgnorePointer(
          child: FadeTransition(
            opacity: _going,
            child: ScaleTransition(
              scale: _shrinking,
              child: NodeCard(
                node: node,
                facts: widget.facts,
                availability: widget.availability,
                selected: false,
                onTap: () {},
                onGrab: (_) {},
                onDrag: (_) {},
                onDrop: () {},
              ),
            ),
          ),
        ),
      ),
    ];
  }

  /// The sockets a line reaches, by the node they belong to. Worked out
  /// once for the frame: asked socket by socket, it is every line of the
  /// scheme read again for each of ninety of them.
  Map<String, Set<PipelineSocket>> _filledSockets() {
    final filled = <String, Set<PipelineSocket>>{};
    for (final link in _state.graph.links) {
      (filled[link.from.nodeId] ??= <PipelineSocket>{}).add(link.from.socket);
      (filled[link.to.nodeId] ??= <PipelineSocket>{}).add(link.to.socket);
    }
    return filled;
  }

  /// Which of [node]'s own sockets a line reaches, as one number: a record
  /// is compared field by field, and a set of its own would be compared by
  /// identity and never match.
  int _filledOf(PipelineNode node, Map<String, Set<PipelineSocket>> filled) {
    var mask = 0;
    for (final socket in filled[node.id] ?? const <PipelineSocket>{}) {
      mask |= 1 << socket.index;
    }
    return mask;
  }

  List<Widget> _nodeLayer(
    BuildContext context,
    PipelineNode node,
    Map<String, Set<PipelineSocket>> filled,
  ) {
    final from = (
      node: node,
      selected: _state.chosen.contains(node.id),
      zoom: _view.zoom,
      facts: widget.facts,
      availability: widget.availability,
      filled: _filledOf(node, filled),
      pulling: _state.drag?.from,
      over: _over,
    );
    if (_drawn[node.id] case final kept? when kept.from == from) return kept.layer;
    final layer = _built(context, node, filled: from.filled, selected: from.selected);
    _drawn[node.id] = (from: from, layer: layer);
    return layer;
  }

  List<Widget> _built(
    BuildContext context,
    PipelineNode node, {
    required int filled,
    required bool selected,
  }) {
    final size = NodeMetrics.sizeOf(node.kind);
    return [
      Positioned(
        // Keyed by the node, so a card taken off the canvas does not hand
        // its place — and the entrance it has already played — to the one
        // drawn after it.
        key: ValueKey(node.id),
        left: node.position.x,
        top: node.position.y,
        width: size.width,
        height: size.height,
        // A layer of its own: the canvas is panned and zoomed by a
        // transform above every card, and without a boundary under it each
        // of them is painted again on every frame of that.
        child: RepaintBoundary(
          child: Appearing(
            key: ValueKey('rising/${node.id}'),
            child: NodeCard(
              node: node,
              facts: widget.facts,
              availability: widget.availability,
              selected: selected,
              onTap: () => widget.bloc.add(PipelineNodeSelected(node.id, add: _adding)),
              onGrab: (at) {
                _dragging = at;
                widget.bloc.add(PipelineNodeGrabbed(node.id));
              },
              onDrag: (at) {
                final from = _dragging ?? at;
                _dragging = at;
                widget.bloc.add(
                  PipelineNodeMoved(
                    node.id,
                    (at.dx - from.dx) / _view.zoom,
                    (at.dy - from.dy) / _view.zoom,
                  ),
                );
              },
              onDrop: () {
                _dragging = null;
                widget.bloc.add(const PipelineArrangementSettled());
              },
              onRemove: node.kind != PipelineNodeKind.character
                  ? null
                  : () => widget.bloc.add(PipelineCharacterRemoved(node.id)),
            ),
          ),
        ),
      ),
      for (final socket in PipelineSocket.values)
        if (socket.owner == node.kind)
          _port(node, socket, filled: filled & (1 << socket.index) != 0),
    ];
  }

  Widget _port(PipelineNode node, PipelineSocket socket, {required bool filled}) {
    final port = PipelinePort(node.id, socket);
    final at = NodeMetrics.portAt(node, socket);
    final drag = _state.drag;
    // The dot shrinks with the canvas; the box that catches the pointer does
    // not. It is as wide on screen whatever the zoom — there is a node's
    // width of empty canvas either side of a socket — and no taller than
    // half a row, so that a socket is never covered by the one under it.
    final wide = NodeMetrics.grabReach / _view.zoom;
    final tall = math.min(wide, NodeMetrics.rowHeight / 2);
    return Positioned(
      left: at.dx - wide,
      top: at.dy - tall,
      width: wide * 2,
      height: tall * 2,
      child: GestureDetector(
        onPanStart: (details) => _startLink(port, details.globalPosition),
        onPanUpdate: (details) => _dragLink(details.globalPosition),
        onPanEnd: (_) => _endLink(),
        onPanCancel: _endLink,
        child: MouseRegion(
          cursor: SystemMouseCursors.precise,
          child: PortDot(
            signal: socket.signal,
            filled: filled,
            offered: drag != null && drag.from != port && _hits.accepts(drag.from, port),
            caught: _over == port,
          ),
        ),
      ),
    );
  }

  /// The badges that cut the lines, each on the curve it cuts; which lines
  /// carry one is [LinkCut.of]'s to say.
  List<Widget> _cutButtons() {
    // Built afresh rather than pruned: a badge whose line is gone is simply
    // not carried over.
    final badges = <PipelineLink, ({Offset at, Widget badge})>{};
    for (final link in _state.graph.links) {
      final cut = LinkCut.of(link);
      final middle = _middleOf(link);
      if (cut == null || middle == null) continue;
      badges[link] = switch (_badges[link]) {
        final kept? when kept.at == middle => kept,
        _ => (
          at: middle,
          badge: LinkCutBadge(
            at: middle,
            cut: cut,
            onCut: () => widget.bloc.add(PipelineLinkCut(link)),
          ),
        ),
      };
    }
    _badges = badges;
    return [for (final kept in badges.values) kept.badge];
  }

  /// The middle of [link]'s curve, or null while an end of it is not drawn.
  Offset? _middleOf(PipelineLink link) {
    final from = _state.graph.node(link.from.nodeId);
    final to = _state.graph.node(link.to.nodeId);
    if (from == null || to == null) return null;
    return LinkGeometry.middleOf(
      NodeMetrics.portAt(from, link.from.socket),
      NodeMetrics.portAt(to, link.to.socket),
    );
  }
}
