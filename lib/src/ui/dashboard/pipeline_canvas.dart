// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../data/services/playback_scheduler.dart';
import '../../domain/app_settings.dart';
import '../../domain/character.dart';
import '../../domain/compute_device.dart';
import '../../domain/game_process.dart';
import '../../domain/model_selection.dart';
import '../../domain/pipeline_graph.dart';
import '../../domain/spoken_language.dart';
import '../compute_names.dart';
import '../language_names.dart';
import '../model_names.dart';
import '../theme.dart';
import 'cubits/pipeline_graph_bloc.dart';

/// How big every node is, and where its sockets sit on it.
///
/// The canvas paints the links, the ports and the cards from these numbers,
/// so a socket is in one place only: move a row here and the curve, the dot
/// and the label all follow.
abstract final class NodeMetrics {
  static const double width = 240;
  static const double characterWidth = 210;
  static const double headerHeight = 42;
  static const double rowHeight = 34;
  static const double summaryHeight = 54;

  /// The middle of the [index]th port row, from the top of the card.
  static double rowCentre(int index) => headerHeight + rowHeight / 2 + index * rowHeight;

  /// How many port rows a node of this kind has.
  static int rowsOf(PipelineNodeKind kind) => switch (kind) {
    PipelineNodeKind.voice || PipelineNodeKind.mix || PipelineNodeKind.character => 2,
    _ => 1,
  };

  static Size sizeOf(PipelineNodeKind kind) => Size(
    kind == PipelineNodeKind.character ? characterWidth : width,
    headerHeight + rowsOf(kind) * rowHeight + summaryHeight,
  );

  /// Where a socket sits, measured from the top-left of its own node.
  static Offset anchorOf(PipelineSocket socket) => switch (socket) {
    PipelineSocket.gameAudio => Offset(width, rowCentre(0)),
    PipelineSocket.speechIn => Offset(0, rowCentre(0)),
    PipelineSocket.speechText => Offset(width, rowCentre(0)),
    PipelineSocket.translationIn => Offset(0, rowCentre(0)),
    PipelineSocket.translatedText => Offset(width, rowCentre(0)),
    PipelineSocket.voiceIn => Offset(0, rowCentre(0)),
    PipelineSocket.voiceAudio => Offset(width, rowCentre(0)),
    PipelineSocket.voiceCast => Offset(width, rowCentre(1)),
    PipelineSocket.mixIn => Offset(0, rowCentre(0)),
    PipelineSocket.mixOut => Offset(width, rowCentre(0)),
    PipelineSocket.mixCast => Offset(0, rowCentre(1)),
    PipelineSocket.streamIn => Offset(0, rowCentre(0)),
    PipelineSocket.characterIn => Offset(0, rowCentre(0)),
    PipelineSocket.readBy => Offset(0, rowCentre(1)),
    PipelineSocket.characterVoice => Offset(characterWidth, rowCentre(0)),
  };

  /// Where a socket sits on the canvas, node and all.
  static Offset portAt(PipelineNode node, PipelineSocket socket) =>
      Offset(node.position.x, node.position.y) + anchorOf(socket);

  /// How near the pointer has to be let go for a port to catch the link,
  /// and how near it has to be pressed to pick one up. Both are distances on
  /// the screen rather than on the canvas: the scheme shrinks to fit a small
  /// window, but the pointer stays the size it was, and a dot drawn six
  /// pixels across cannot be taken hold of.
  static const double catchRadius = 34;
  static const double grabReach = dotRadius + 9;

  static const double dotRadius = 7;
}

/// What the nodes write on themselves. The canvas draws the pipeline as it
/// is configured, so it is handed the configuration rather than four cubits.
class PipelineFacts {
  const PipelineFacts({
    required this.settings,
    required this.selection,
    this.process,
    this.characters = const [],
    this.activeBackends = const {},
    this.running = false,
    this.paused = false,
    this.recordingVoice = false,
  });

  final AppSettings settings;
  final ModelSelection selection;
  final GameProcess? process;
  final List<Character> characters;

  /// What a running session reported it actually settled on.
  final Map<ComputeStage, ComputeBackend> activeBackends;
  final bool running;

  /// Whether that session is resting. The cast may be rewired either way;
  /// this is only so the toolbar can offer to wake it.
  final bool paused;

  /// Whether a card is being recorded on the characters screen. That session
  /// listens to the game it started with, and the game is one choice shared
  /// by every screen — so it is not to be changed from here either, idle as
  /// the pipeline itself is.
  final bool recordingVoice;

  Character? character(String? id) {
    if (id == null) return null;
    for (final character in characters) {
      if (character.id == id) return character;
    }
    return null;
  }

  ComputeBackend backendOf(ComputeStage stage, ComputeAvailability availability) =>
      activeBackends[stage] ?? settings.backendFor(stage, availability);
}

/// Why a link came to nothing, in the interface language.
String describeConnectionRefusal(AppLocalizations l10n, ConnectionRefusal reason) =>
    switch (reason) {
      ConnectionRefusal.signal => l10n.pipelineRefusalSignal,
      ConnectionRefusal.direction => l10n.pipelineRefusalDirection,
      ConnectionRefusal.sameNode => l10n.pipelineRefusalSameNode,
      ConnectionRefusal.unsupported => l10n.pipelineRefusalUnsupported,
      ConnectionRefusal.loop => l10n.pipelineRefusalLoop,
      ConnectionRefusal.locked => l10n.pipelineRefusalLocked,
    };

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

class _PipelineCanvasState extends State<PipelineCanvas> {
  final _viewport = GlobalKey();

  /// The port the pointer is over while a link is being pulled, so it can
  /// be shown as the one that would catch it.
  PipelinePort? _over;

  /// Where the pointer was when a node last answered it, on the screen. What
  /// a node moves is the distance from here, so it keeps up with the pointer
  /// exactly instead of with its own idea of how far it has come.
  Offset? _dragging;

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

  /// Where [at] on the screen lands on the canvas.
  GraphPoint _onCanvas(Offset at) {
    final box = _viewport.currentContext?.findRenderObject() as RenderBox?;
    final local = box?.globalToLocal(at) ?? at;
    return _view.toCanvas(GraphPoint(local.dx, local.dy));
  }

  /// Every node the band covers, by the card it draws rather than by the
  /// corner it starts at: a card half inside the band was meant.
  Set<String> _caughtBy(Rect band) => {
    for (final node in _state.graph.nodes)
      if (band.overlaps(
        Rect.fromLTWH(
          node.position.x,
          node.position.y,
          NodeMetrics.sizeOf(node.kind).width,
          NodeMetrics.sizeOf(node.kind).height,
        ),
      ))
        node.id,
  };

  PipelineGraphState get _state => widget.state;
  GraphView get _view => _state.layout.view;

  /// [global] as a place on the canvas, zoom and pan taken out.
  GraphPoint _toCanvas(Offset global) {
    final box = _viewport.currentContext?.findRenderObject() as RenderBox?;
    final local = box?.globalToLocal(global) ?? global;
    return _view.toCanvas(GraphPoint(local.dx, local.dy));
  }

  /// The socket near [point], if the link let go there should catch one.
  PipelinePort? _portNear(GraphPoint point, {required PipelinePort from}) {
    final at = Offset(point.x, point.y);
    PipelinePort? best;
    var nearest = NodeMetrics.catchRadius / _view.zoom;
    for (final node in _state.graph.nodes) {
      for (final socket in PipelineSocket.values) {
        if (socket.owner != node.kind) continue;
        final distance = (NodeMetrics.portAt(node, socket) - at).distance;
        if (distance > nearest) continue;
        final port = PipelinePort(node.id, socket);
        if (port == from) continue;
        nearest = distance;
        best = port;
      }
    }
    return best;
  }

  /// Whether a link from [from] would be accepted by [port] — what the ring
  /// around a socket shows while the pointer is carrying one.
  bool _accepts(PipelinePort from, PipelinePort port) => proposeConnection(
    _state.graph,
    from,
    port,
    characters: widget.facts.characters,
  ) is! RefusedConnection;

  void _startLink(PipelinePort port, Offset global) {
    setState(() => _over = null);
    widget.bloc.add(PipelineLinkStarted(port, _toCanvas(global)));
  }

  void _dragLink(Offset global) {
    final at = _toCanvas(global);
    final from = _state.drag?.from;
    final over = from == null ? null : _portNear(at, from: from);
    if (over != _over) setState(() => _over = over);
    widget.bloc.add(PipelineLinkDragged(at));
  }

  void _endLink() {
    widget.bloc.add(PipelineLinkReleased(_over));
    setState(() => _over = null);
  }

  /// The whole scheme seen at once, in a window of [viewport].
  ///
  /// The canvas works this out rather than the bloc: where a node ends is a
  /// matter of how it is drawn, which is this file's business.
  GraphView _fitted(Size viewport) {
    var left = double.infinity;
    var top = double.infinity;
    var right = -double.infinity;
    var bottom = -double.infinity;
    for (final node in _state.graph.nodes) {
      final size = NodeMetrics.sizeOf(node.kind);
      left = math.min(left, node.position.x);
      top = math.min(top, node.position.y);
      right = math.max(right, node.position.x + size.width);
      bottom = math.max(bottom, node.position.y + size.height);
    }
    if (left > right || viewport.isEmpty) return const GraphView(placed: true);
    const margin = 28.0;
    final width = right - left;
    final height = bottom - top;
    final zoom = math
        .min(
          (viewport.width - margin * 2) / width,
          (viewport.height - margin * 2) / height,
        )
        .clamp(GraphView.smallestZoom, 1.0);
    return GraphView(
      x: (viewport.width - width * zoom) / 2 - left * zoom,
      y: (viewport.height - height * zoom) / 2 - top * zoom,
      zoom: zoom,
      placed: true,
    );
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
              widget.bloc.add(PipelineViewSet(_fitted(constraints.biggest)));
            }
          });
        }
        return _canvas(context, view);
      },
    );
  }

  Widget _canvas(BuildContext context, GraphView view) {
    return ClipRect(
      child: Listener(
        key: _viewport,
        onPointerSignal: (signal) {
          if (signal is! PointerScrollEvent) return;
          final box = _viewport.currentContext?.findRenderObject() as RenderBox?;
          final local = box?.globalToLocal(signal.position) ?? signal.position;
          widget.bloc.add(
            PipelineViewZoomed(
              view.zoom * (signal.scrollDelta.dy > 0 ? 0.9 : 1.1),
              GraphPoint(local.dx, local.dy),
            ),
          );
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.bloc.add(const PipelineNodeSelected(null)),
          // Empty space drags the canvas, as it always has; with control
          // held it draws a band over the nodes instead, which is the one
          // gesture that needs a modifier to tell it from panning.
          onPanStart: (details) {
            if (!_banding) return;
            setState(() {
              _bandFrom = _onCanvas(details.globalPosition);
              _bandTo = _bandFrom;
            });
          },
          onPanUpdate: (details) {
            if (_bandFrom == null) {
              widget.bloc.add(PipelineViewPanned(details.delta.dx, details.delta.dy));
              return;
            }
            setState(() => _bandTo = _onCanvas(details.globalPosition));
          },
          onPanEnd: (_) {
            final band = _band;
            if (band != null) {
              // A band drawn with shift held adds to what was chosen; on
              // its own it is the whole choice.
              final caught = _caughtBy(band);
              widget.bloc.add(
                PipelineSelectionSet(_adding ? {..._state.chosen, ...caught} : caught),
              );
              setState(() {
                _bandFrom = null;
                _bandTo = null;
              });
              return;
            }
            widget.bloc.add(const PipelineArrangementSettled());
          },
          child: CustomPaint(
            painter: _DotFieldPainter(view),
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
                          painter: _LinkPainter(
                            graph: _state.graph,
                            drag: _state.drag,
                            over: _over,
                          ),
                        ),
                      ),
                      for (final node in _state.graph.nodes) ..._nodeLayer(context, node),
                      ..._cutButtons(context),
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

  List<Widget> _nodeLayer(BuildContext context, PipelineNode node) {
    final size = NodeMetrics.sizeOf(node.kind);
    return [
      Positioned(
        left: node.position.x,
        top: node.position.y,
        width: size.width,
        height: size.height,
        child: _NodeCard(
          node: node,
          facts: widget.facts,
          availability: widget.availability,
          selected: _state.chosen.contains(node.id),
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
      for (final socket in PipelineSocket.values)
        if (socket.owner == node.kind) _port(node, socket),
    ];
  }

  Widget _port(PipelineNode node, PipelineSocket socket) {
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
          child: _PortDot(
            signal: socket.signal,
            filled: socket.isInput
                ? _state.graph.linkInto(port) != null
                : _state.graph.links.any((link) => link.from == port),
            offered: drag != null && drag.from != port && _accepts(drag.from, port),
            caught: _over == port,
          ),
        ),
      ),
    );
  }

  /// The badge that cuts a substitution, sitting on the curve it cuts. Only
  /// the links between characters carry one: the route is never cut, it is
  /// drawn elsewhere.
  List<Widget> _cutButtons(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final buttons = <Widget>[];
    for (final link in _state.graph.links) {
      // The way into the pipeline comes apart the same way a substitution
      // does, by the button on the line itself.
      final route = link.from.socket == PipelineSocket.gameAudio;
      final reader =
          link.from.socket == PipelineSocket.characterVoice &&
          link.to.socket == PipelineSocket.readBy;
      // The cast comes out of the mix whole, so any of its lines will do.
      final cast = link.to.socket == PipelineSocket.mixCast;
      // The dashed line that counts a card among the voices of the game.
      final heard = link.to.socket == PipelineSocket.characterIn;
      if (!route && !reader && !cast && !heard) continue;
      final from = _state.graph.node(link.from.nodeId);
      final to = _state.graph.node(link.to.nodeId);
      if (from == null || to == null) continue;
      final middle = _LinkPainter.middleOf(
        NodeMetrics.portAt(from, link.from.socket),
        NodeMetrics.portAt(to, link.to.socket),
      );
      buttons.add(
        Positioned(
          left: middle.dx - 15,
          top: middle.dy - 15,
          width: 30,
          height: 30,
          child: Tooltip(
            // Four kinds of line come apart here and they part with
            // different things: one card takes its own part back, a card
            // stops being counted among the voices of the game, the cast
            // leaves the mix, the pipeline loses what feeds it.
            message: switch ((route, cast, heard)) {
              (true, _, _) => l10n.pipelineCutRoute,
              (_, true, _) => l10n.pipelineCutCast,
              (_, _, true) => l10n.pipelineCutHeard,
              _ => l10n.pipelineCutLink,
            },
            child: Material(
              shape: const CircleBorder(side: BorderSide(color: LoreDubPalette.graphite)),
              color: LoreDubPalette.raised,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => widget.bloc.add(PipelineLinkCut(link)),
                child: const Icon(Icons.link_off_rounded, size: 16),
              ),
            ),
          ),
        ),
      );
    }
    return buttons;
  }
}

/// The field the scheme sits on: dots that move and grow with the canvas, so
/// panning is visible even where there is no node.
class _DotFieldPainter extends CustomPainter {
  const _DotFieldPainter(this.view);

  final GraphView view;

  static const double spacing = 26;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = LoreDubPalette.canvas);
    final step = spacing * view.zoom;
    if (step < 6) return;
    final dot = Paint()..color = LoreDubPalette.outline.withValues(alpha: 0.55);
    final radius = math.max(0.8, 1.1 * view.zoom);
    final startX = view.x % step;
    final startY = view.y % step;
    for (var x = startX - step; x < size.width + step; x += step) {
      for (var y = startY - step; y < size.height + step; y += step) {
        canvas.drawCircle(Offset(x, y), radius, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_DotFieldPainter old) =>
      old.view.x != view.x || old.view.y != view.y || old.view.zoom != view.zoom;
}

/// The curves. The route is a solid orange line; a voice given to another
/// character is a dashed graphite one, so what is signal and what is casting
/// are told apart without reading a label.
class _LinkPainter extends CustomPainter {
  const _LinkPainter({required this.graph, this.drag, this.over});

  final PipelineGraph graph;
  final PipelineLinkDrag? drag;
  final PipelinePort? over;

  /// How far the curve leaves a socket before it bends, so two nodes side by
  /// side are joined by a bow rather than a corner.
  static double _reach(Offset from, Offset to) => math.max(60, (to.dx - from.dx).abs() * 0.5);

  static Path pathBetween(Offset from, Offset to) {
    final reach = _reach(from, to);
    return Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(from.dx + reach, from.dy, to.dx - reach, to.dy, to.dx, to.dy);
  }

  /// The middle of the curve, where its badge sits.
  static Offset middleOf(Offset from, Offset to) {
    final reach = _reach(from, to);
    final c1 = Offset(from.dx + reach, from.dy);
    final c2 = Offset(to.dx - reach, to.dy);
    // The cubic at t = 0.5, which is the eighth-sum of the four points.
    return (from + c1 * 3 + c2 * 3 + to) / 8;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final link in graph.links) {
      final from = graph.node(link.from.nodeId);
      final to = graph.node(link.to.nodeId);
      if (from == null || to == null) continue;
      final path = pathBetween(
        NodeMetrics.portAt(from, link.from.socket),
        NodeMetrics.portAt(to, link.to.socket),
      );
      final cast = link.signal == PipelineSignal.voice;
      canvas.drawPath(
        cast ? _dashed(path) : path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cast ? 1.6 : 2.4
          ..strokeCap = StrokeCap.round
          ..color = cast ? LoreDubPalette.graphite : LoreDubPalette.orange,
      );
    }
    if (drag case final pulling?) {
      final node = graph.node(pulling.from.nodeId);
      if (node == null) return;
      final from = NodeMetrics.portAt(node, pulling.from.socket);
      final to = Offset(pulling.at.x, pulling.at.y);
      final path = pulling.from.isOutput ? pathBetween(from, to) : pathBetween(to, from);
      canvas.drawPath(
        _dashed(path),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..color = over == null ? LoreDubPalette.mutedInk : LoreDubPalette.orange,
      );
    }
  }

  /// [path] as a dashed copy of itself. Flutter strokes whole paths only, so
  /// the dashes are cut out of the metrics by hand.
  Path _dashed(Path path, {double on = 9, double off = 7}) {
    final dashes = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        dashes.addPath(
          metric.extractPath(distance, math.min(distance + on, metric.length)),
          Offset.zero,
        );
        distance += on + off;
      }
    }
    return dashes;
  }

  @override
  bool shouldRepaint(_LinkPainter old) =>
      old.graph != graph || old.drag != drag || old.over != over;
}

/// A socket: hollow while nothing is attached, filled when something is,
/// ringed while the link being pulled could land on it.
class _PortDot extends StatelessWidget {
  const _PortDot({
    required this.signal,
    required this.filled,
    required this.offered,
    required this.caught,
  });

  final PipelineSignal signal;
  final bool filled;
  final bool offered;
  final bool caught;

  @override
  Widget build(BuildContext context) {
    final color = signal == PipelineSignal.voice ? LoreDubPalette.graphite : LoreDubPalette.orange;
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: caught ? 22 : (offered ? 18 : NodeMetrics.dotRadius * 2),
        height: caught ? 22 : (offered ? 18 : NodeMetrics.dotRadius * 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color : LoreDubPalette.raised,
          border: Border.all(color: caught || offered ? LoreDubPalette.orange : color, width: 2),
        ),
      ),
    );
  }
}

/// One node, drawn as a card of the same family as the model tiles: a header
/// naming the stage, a row for each socket, and a line of what it is set to.
class _NodeCard extends StatelessWidget {
  const _NodeCard({
    required this.node,
    required this.facts,
    required this.availability,
    required this.selected,
    required this.onTap,
    required this.onGrab,
    required this.onDrag,
    required this.onDrop,
    this.onRemove,
  });

  final PipelineNode node;
  final PipelineFacts facts;
  final ComputeAvailability availability;
  final bool selected;
  final VoidCallback onTap;

  /// Where the pointer took hold, and where it has got to, both on the
  /// screen. Not the drag's own delta: that is reported in the card's own
  /// coordinates, and the card moves out from under the pointer as it is
  /// dragged, so every step would be measured against a card that had
  /// already answered the step before it.
  final void Function(Offset at) onGrab;
  final void Function(Offset at) onDrag;
  final VoidCallback onDrop;

  /// Takes the node off the canvas. Only a card has one: the stages of the
  /// pipeline are always drawn, bypassed or unrouted as they may be.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: onTap,
      onPanStart: (details) => onGrab(details.globalPosition),
      onPanUpdate: (details) => onDrag(details.globalPosition),
      onPanEnd: (_) => onDrop(),
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Opacity(
          opacity: node.unrouted ? 0.55 : 1,
          child: Container(
            decoration: BoxDecoration(
              color: _paint.body,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? _paint.chosen : LoreDubPalette.outline,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x22171717),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(context, l10n),
                for (final row in _rows(l10n)) row,
                Expanded(child: _summary(context, l10n)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, AppLocalizations l10n) => Container(
    height: NodeMetrics.headerHeight,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: _paint.header,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
      border: Border(bottom: BorderSide(color: _paint.muted.withValues(alpha: 0.25))),
    ),
    child: Row(
      children: [
        Icon(_icon, size: 18, color: _paint.ink),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _title(l10n),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _paint.ink),
          ),
        ),
        if (onRemove case final remove?)
          // On the card itself rather than only in the panel: a card is put
          // on the canvas by hand and taken off the same way.
          SizedBox(
            width: 26,
            height: 26,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 16,
              tooltip: l10n.pipelineRemoveNode,
              color: _paint.muted,
              icon: const Icon(Icons.close_rounded),
              onPressed: remove,
            ),
          ),
        if (node.unrouted)
          Text(
            l10n.pipelineUnrouted.toUpperCase(),
            style: TextStyle(
              fontFamily: LoreDubFonts.mono,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: _paint.muted,
            ),
          ),
      ],
    ),
  );

  /// One row per port row, labelled on the side its socket is on.
  List<Widget> _rows(AppLocalizations l10n) => switch (node.kind) {
    PipelineNodeKind.source => [
      _PortRow(paint: _paint, right: l10n.pipelineSocketGameAudio),
    ],
    PipelineNodeKind.recognition => [
      _PortRow(paint: _paint, left: l10n.pipelineSocketSpeech, right: l10n.pipelineSocketText),
    ],
    PipelineNodeKind.translation => [
      _PortRow(paint: _paint, left: l10n.pipelineSocketText, right: l10n.pipelineSocketText),
    ],
    PipelineNodeKind.voice => [
      _PortRow(paint: _paint, left: l10n.pipelineSocketText, right: l10n.pipelineSocketAudio),
      _PortRow(paint: _paint, right: l10n.pipelineSocketCast),
    ],
    PipelineNodeKind.mix => [
      _PortRow(paint: _paint, left: l10n.pipelineSocketAudio, right: l10n.pipelineSocketAudio),
      _PortRow(paint: _paint, left: l10n.pipelineSocketCast),
    ],
    PipelineNodeKind.output => [_PortRow(paint: _paint, left: l10n.pipelineSocketAudio)],
    PipelineNodeKind.character => [
      _PortRow(paint: _paint, left: l10n.pipelineSocketCharacter, right: l10n.pipelineSocketVoice),
      _PortRow(paint: _paint, left: l10n.pipelineSocketVoice),
    ],
  };

  Widget _summary(BuildContext context, AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _headline(context, l10n),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            height: 1.25,
            fontWeight: FontWeight.w600,
            color: _paint.ink,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _note(context, l10n),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: LoreDubFonts.mono,
            fontSize: 9,
            height: 1.2,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.4,
            color: _paint.muted,
          ),
        ),
      ],
    ),
  );

  _NodePaint get _paint => switch (node.kind) {
    PipelineNodeKind.source || PipelineNodeKind.output => _NodePaint.ends,
    PipelineNodeKind.character => _NodePaint.cast,
    _ => _NodePaint.plain,
  };

  IconData get _icon => switch (node.kind) {
    PipelineNodeKind.source => Icons.videogame_asset_rounded,
    PipelineNodeKind.recognition => Icons.graphic_eq_rounded,
    PipelineNodeKind.translation => Icons.translate_rounded,
    PipelineNodeKind.voice => Icons.record_voice_over_rounded,
    PipelineNodeKind.mix => Icons.multitrack_audio_rounded,
    PipelineNodeKind.output => Icons.volume_up_rounded,
    PipelineNodeKind.character => Icons.person_rounded,
  };

  String _title(AppLocalizations l10n) => switch (node.kind) {
    PipelineNodeKind.source => l10n.pipelineNodeSource,
    PipelineNodeKind.recognition => l10n.pipelineNodeRecognition,
    PipelineNodeKind.translation => l10n.pipelineNodeTranslation,
    PipelineNodeKind.voice => l10n.pipelineNodeVoice,
    PipelineNodeKind.mix => l10n.pipelineNodeMix,
    PipelineNodeKind.output => l10n.pipelineNodeOutput,
    PipelineNodeKind.character => facts.character(node.characterId)?.name ?? l10n.charactersNewName,
  };

  /// What the node is set to, in one line.
  String _headline(BuildContext context, AppLocalizations l10n) {
    final settings = facts.settings;
    return switch (node.kind) {
      PipelineNodeKind.source => facts.process?.name ?? l10n.pipelineNoProcess,
      PipelineNodeKind.recognition => switch (facts.selection.recognition?.model) {
        final model? => whisperShortName(model),
        _ => l10n.pipelineNoModel,
      },
      // Whisper is run with -tr, so what reaches the translator is English
      // whatever the game speaks; the language Live listens in says nothing
      // about this stage and used to be written here as if it did.
      PipelineNodeKind.translation =>
        '${spokenLanguageName(l10n, fallbackSpokenLanguage)}'
            ' → ${translationTargetName(l10n, settings.targetLanguage)}',
      PipelineNodeKind.voice => switch (settings.voiceMode) {
        VoiceMode.original => l10n.voiceOriginal,
        VoiceMode.automatic => l10n.voiceAutomatic,
        VoiceMode.chosen => _chosenVoice(l10n),
      },
      PipelineNodeKind.mix =>
        settings.overlapVoices
            ? l10n.pipelineMixVoices(overlappingVoices)
            : l10n.pipelineMixOneVoice,
      PipelineNodeKind.output => l10n.pipelineOutputDefault,
      PipelineNodeKind.character => _characterHeadline(l10n),
    };
  }

  /// The voice a fixed choice reads every line in, named as the picker
  /// names it rather than by its bare identifier.
  String _chosenVoice(AppLocalizations l10n) {
    final chosen = facts.selection.voice;
    for (final option in facts.selection.availableVoices) {
      if (option.id == chosen) return voiceLabel(l10n, option);
    }
    return chosen;
  }

  String _characterHeadline(AppLocalizations l10n) {
    final reader = facts.character(facts.character(node.characterId)?.voicedBy);
    return reader == null ? l10n.charactersOwnVoice : l10n.pipelineReadBy(reader.name);
  }

  String _note(BuildContext context, AppLocalizations l10n) {
    final settings = facts.settings;
    String device(ComputeStage stage) =>
        computeBackendName(l10n, facts.backendOf(stage, availability)).toUpperCase();
    return switch (node.kind) {
      PipelineNodeKind.source =>
        settings.audioCaptureSource == AudioCaptureSource.process
            ? l10n.sourceProcess.toUpperCase()
            : l10n.sourceSystem.toUpperCase(),
      PipelineNodeKind.recognition => device(ComputeStage.recognition),
      PipelineNodeKind.translation => device(ComputeStage.translation),
      PipelineNodeKind.voice =>
        facts.selection.clonesVoice
            ? device(ComputeStage.voiceConversion)
            : device(ComputeStage.speech),
      PipelineNodeKind.mix =>
        settings.overlapVoices
            ? l10n.pipelineMixOverlapping.toUpperCase()
            : l10n.pipelineMixInTurn.toUpperCase(),
      PipelineNodeKind.output =>
        l10n.pipelineOutputOriginal((settings.originalVolume * 100).round()).toUpperCase(),
      PipelineNodeKind.character => _characterNote(l10n),
    };
  }

  String _characterNote(AppLocalizations l10n) {
    final character = facts.character(node.characterId);
    if (character == null) return '';
    if (facts.settings.originalVoice == false) return l10n.pipelineCharacterNeedsOriginal;
    return character.vector.isEmpty
        ? l10n.charactersNoVoice
        : l10n.charactersHeard(character.seconds.toStringAsFixed(1));
  }
}

/// A row of the card that a socket sits on, labelled towards its own edge.
/// What one node is drawn in.
///
/// The two ends of the pipeline are orange -- where the game's sound comes
/// in and where the dubbing leaves -- so the eye finds them without reading
/// them, and a card of the cast is dark, the way the open section is drawn
/// in the navigation. Everything between them keeps the raised face the
/// model tiles use, and only what is written on a node changes with the
/// face under it.
class _NodePaint {
  const _NodePaint({
    required this.body,
    required this.header,
    required this.ink,
    required this.muted,
    required this.chosen,
  });

  static const plain = _NodePaint(
    body: LoreDubPalette.raised,
    header: LoreDubPalette.panel,
    ink: LoreDubPalette.ink,
    muted: LoreDubPalette.mutedInk,
    chosen: LoreDubPalette.orange,
  );

  static const ends = _NodePaint(
    body: LoreDubPalette.orange,
    header: LoreDubPalette.orange,
    ink: LoreDubPalette.ink,
    // The orange carries a darker shade of its own text rather than the
    // grey of the panels, which it swallows.
    muted: Color(0xCC171717),
    chosen: LoreDubPalette.ink,
  );

  static const cast = _NodePaint(
    body: LoreDubPalette.graphite,
    header: LoreDubPalette.graphite,
    ink: LoreDubPalette.raised,
    muted: Color(0xAAF7F5F0),
    chosen: LoreDubPalette.orange,
  );

  final Color body;
  final Color header;
  final Color ink;
  final Color muted;

  /// The border of a node the pointer has chosen. Orange on the orange ends
  /// would be no mark at all.
  final Color chosen;
}

class _PortRow extends StatelessWidget {
  const _PortRow({required this.paint, this.left, this.right});

  final _NodePaint paint;
  final String? left;
  final String? right;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: NodeMetrics.rowHeight,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          if (left != null) Expanded(child: _label(left!, TextAlign.left)),
          if (left == null) const Spacer(),
          if (right != null) Expanded(child: _label(right!, TextAlign.right)),
        ],
      ),
    ),
  );

  Widget _label(String text, TextAlign align) => Text(
    text,
    textAlign: align,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontFamily: LoreDubFonts.mono,
      fontSize: 9,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: paint.muted,
    ),
  );
}
