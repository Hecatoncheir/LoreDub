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
import 'pipeline_facts.dart';
import 'graph_hit_tester.dart';
import 'scheme_diff.dart';
import 'dot_field_painter.dart';
import 'link_painter.dart';
import 'choice_fade.dart';
import 'node_inputs.dart';
import 'node_metrics.dart';
import 'node_layer_actions.dart';
import 'node_layer_cache.dart';
import 'leaving_node.dart';

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

class _PipelineCanvasState extends State<PipelineCanvas> with TickerProviderStateMixin {
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

  /// How long the field takes to come round to a card being picked out.
  /// Shorter than an edit: nothing is drawn or taken away, and the answer
  /// to a click should be felt rather than waited for.
  static const _choosing = Duration(milliseconds: 200);

  /// Runs whenever the choice changes, and is what the field parts over.
  late final AnimationController _picking = AnimationController(vsync: this, duration: _choosing)
    ..addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      // Everything has arrived; the fade holds where nothing is on its way.
      setState(() => _fade = ChoiceFade(chosen: _fade.chosen));
    });

  late final Animation<double> _picked = CurvedAnimation(
    parent: _picking,
    curve: Curves.easeOutCubic,
  );

  /// Which cards the field answers to, and where the ones still on their
  /// way stood when this run began.
  ChoiceFade _fade = const ChoiceFade();

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
  /// as, and the badge on each line.
  final _layers = NodeLayerCache();
  final _badges = BadgeCache();

  /// The sockets that would take the line being pulled, by node, and what
  /// that was worked out for: the graph does not change under a pulled
  /// line, so this is asked once a pull rather than once a frame.
  ({PipelineGraph graph, PipelinePort from, Object characters, Map<String, int> masks})? _offers;

  /// What every layer tells the canvas, made once so that a kept layer is
  /// still the same widget.
  late final _actions = NodeLayerActions(
    onTap: (id) => widget.bloc.add(PipelineNodeSelected(id, add: _adding)),
    onGrab: (id, at) {
      _dragging = at;
      widget.bloc.add(PipelineNodeGrabbed(id));
    },
    onDrag: (id, at) {
      final from = _dragging ?? at;
      _dragging = at;
      widget.bloc.add(
        PipelineNodeMoved(id, (at.dx - from.dx) / _view.zoom, (at.dy - from.dy) / _view.zoom),
      );
    },
    onDrop: () {
      _dragging = null;
      widget.bloc.add(const PipelineArrangementSettled());
    },
    onRemove: (id) => widget.bloc.add(PipelineCharacterRemoved(id)),
    onLinkStart: _startLink,
    onLinkToggle: _toggleLink,
    onLinkDrag: _dragLink,
    onLinkEnd: _endLink,
  );

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
    // The scheme opens on whatever was chosen last, parted already rather
    // than parting itself in front of the player.
    _fade = ChoiceFade(chosen: widget.state.chosen);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A player who has turned animation off in Windows is shown the end of
    // every one of these at once.
    final still = MediaQuery.disableAnimationsOf(context);
    _drawing.duration = still ? Duration.zero : _motion;
    _picking.duration = still ? Duration.zero : _choosing;
    // What is kept was built against the language and the theme that were
    // around it, so a change of either throws all of it away.
    _layers.clear();
    _badges.clear();
  }

  @override
  void didUpdateWidget(PipelineCanvas old) {
    super.didUpdateWidget(old);
    _followChoice(old.state.chosen);
    final diff = SchemeDiff.between(old.state.graph, widget.state.graph);
    if (diff.isEmpty) return;
    _appearing = diff.appearing;
    _fading = diff.fading;
    _leaving = diff.leaving;
    _arriving = diff.arriving;
    _drawing.forward(from: 0);
  }

  /// The field follows the choice from wherever it had got to.
  void _followChoice(Set<String> was) {
    final now = widget.state.chosen;
    if (now.length == was.length && now.containsAll(was)) return;
    _fade = _fade.towards(now, _picked.value);
    if (_fade.settled) return;
    _picking.forward(from: 0);
  }

  @override
  void dispose() {
    _picking.dispose();
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

  /// A line drawn without a pointer: the first socket takes it up, the
  /// second puts it down, and the one it started from lets it go. It goes
  /// through the same events a drag does, so what a link may join and what
  /// it changes is answered in one place.
  void _toggleLink(PipelinePort port) {
    final drag = _state.drag;
    if (drag == null) {
      final node = _state.graph.node(port.nodeId);
      if (node == null) return;
      final at = NodeMetrics.portAt(node, port.socket);
      widget.bloc.add(PipelineLinkStarted(port, GraphPoint(at.dx, at.dy)));
      return;
    }
    widget.bloc.add(PipelineLinkReleased(drag.from == port ? null : port));
    setState(() => _over = null);
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
    final layers = _layers.layersFor(_inputs(), _actions);
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
              fade: _fade,
              picked: _picked,
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
                      for (final node in _leaving)
                        LeavingNode(
                          key: ValueKey('leaving/${node.id}'),
                          node: node,
                          facts: widget.facts,
                          availability: widget.availability,
                          opacity: _going,
                          scale: _shrinking,
                        ),
                      ...layers,
                      ..._badges.badgesFor(
                        _state.graph,
                        (link) => widget.bloc.add(PipelineLinkCut(link)),
                      ),
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

  /// What each node's layer is drawn from this frame.
  Iterable<NodeInputs> _inputs() {
    final filled = _filledSockets();
    final offered = _offeredSockets();
    return [
      for (final node in _state.graph.nodes)
        (
          node: node,
          selected: _state.chosen.contains(node.id),
          zoom: _view.zoom,
          facts: widget.facts,
          availability: widget.availability,
          filled: _filledOf(node, filled),
          offered: offered[node.id] ?? 0,
          pulling: _state.drag?.from,
          over: _over,
        ),
    ];
  }

  /// The sockets of each node that would take the line being pulled, as
  /// one number a node, and none while no line is.
  Map<String, int> _offeredSockets() {
    final from = _state.drag?.from;
    if (from == null) return const {};
    final kept = _offers;
    if (kept != null &&
        identical(kept.graph, _state.graph) &&
        kept.from == from &&
        identical(kept.characters, widget.facts.characters)) {
      return kept.masks;
    }
    final hits = _hits;
    final masks = <String, int>{};
    for (final node in _state.graph.nodes) {
      var mask = 0;
      for (final socket in PipelineSocket.values) {
        final port = PipelinePort(node.id, socket);
        if (socket.owner != node.kind || port == from || !hits.accepts(from, port)) continue;
        mask |= 1 << socket.index;
      }
      masks[node.id] = mask;
    }
    _offers = (
      graph: _state.graph,
      from: from,
      characters: widget.facts.characters,
      masks: masks,
    );
    return masks;
  }
}
