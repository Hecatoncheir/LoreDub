// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/compute_device.dart';
import '../../../domain/pipeline_graph.dart';
import '../../theme.dart';
import '../bloc/pipeline_graph_bloc.dart';
import 'canvas_gestures.dart';
import 'pipeline_facts.dart';
import 'graph_hit_tester.dart';
import 'scheme_diff.dart';
import 'dot_field_painter.dart';
import 'link_painter.dart';
import 'choice_fade.dart';
import 'node_inputs.dart';
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

  /// What the pointer does, turned into what the bloc is told. The canvas
  /// draws what it holds -- the socket under a pulled line, the band -- and
  /// is told to when it changes.
  late final _gestures = CanvasGestures(
    add: (event) => widget.bloc.add(event),
    state: () => widget.state,
    hits: () => _hits,
  )..addListener(_redraw);

  void _redraw() {
    if (mounted) setState(() {});
  }

  /// What every layer tells the canvas, made once so that a kept layer is
  /// still the same widget.
  late final _actions = NodeLayerActions(
    onTap: (id) => _gestures.select(id, adding: _adding),
    onGrab: _gestures.grab,
    onDrag: _gestures.carry,
    onDrop: _gestures.drop,
    onRemove: _gestures.remove,
    onSwitch: _gestures.switchNode,
    onLinkStart: (port, global) => _gestures.pullLink(port, _toCanvas(global)),
    onLinkToggle: _gestures.toggleLink,
    onLinkDrag: (global) => _gestures.carryLink(_toCanvas(global)),
    onLinkEnd: _gestures.releaseLink,
  );

  final _viewport = GlobalKey();

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
    // around it, so a change of either throws all of it away. A card and a
    // badge read both inside their own `build`, so the framework would
    // rebuild them anyway -- `canvas_theme_test.dart` holds them to that,
    // cache and all -- and this is what keeps that true of anything put in
    // them later.
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
    _gestures.dispose();
    _picking.dispose();
    _drawing.dispose();
    super.dispose();
  }

  /// Whether a modifier is down right now. Read at the moment of the
  /// gesture rather than kept: a key let go while the pointer is down must
  /// not turn a band into a pan half way through.
  static bool get _adding => HardwareKeyboard.instance.isShiftPressed;
  static bool get _banding =>
      HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;

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
    _gestures.wheel(signal.scrollDelta.dy, GraphPoint(local.dx, local.dy));
  }

  Widget _canvas(BuildContext context, GraphView view) {
    final layers = _layers.layersFor(_inputs(), _actions);
    return ClipRect(
      child: Listener(
        key: _viewport,
        onPointerSignal: _zoom,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _gestures.clearChoice,
          // Empty space drags the canvas, as it always has; with control
          // held it draws a band over the nodes instead, which is the one
          // gesture that needs a modifier to tell it from panning.
          onPanStart: (details) =>
              _gestures.pressSpace(_toCanvas(details.globalPosition), banding: _banding),
          onPanUpdate: (details) =>
              _gestures.dragSpace(details.delta, _toCanvas(details.globalPosition)),
          onPanEnd: (_) => _gestures.releaseSpace(adding: _adding),
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
              colors: context.colors,
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
                            over: _gestures.over,
                            appearing: _appearing,
                            fading: _fading,
                            leaving: _leaving,
                            grown: _grown,
                            colors: context.colors,
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
                      ..._badges.badgesFor(_state.graph, _gestures.cut),
                      if (_gestures.band case final band?)
                        Positioned.fromRect(
                          rect: band,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: context.colors.accent.withValues(alpha: 0.08),
                                border: Border.all(color: context.colors.accent),
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
          over: _gestures.over,
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
      for (final socket in node.sockets) {
        final port = PipelinePort(node.id, socket);
        if (port == from || !hits.accepts(from, port)) continue;
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
