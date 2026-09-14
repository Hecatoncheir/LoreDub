// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// The shelf of kept schemes: a card each, with a picture of the scheme on
/// it, under the graph's own toolbar.
///
/// The picture is drawn from the scheme itself rather than kept as an image:
/// it is the same nodes and the same links, at the size of a thumbnail, so
/// it can never show a scheme the file no longer holds.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../../domain/character.dart';
import '../../domain/pipeline_graph.dart';
import '../../domain/saved_pipeline.dart';
import '../theme.dart';
import 'pipeline_canvas.dart' show NodeMetrics;

class PipelineShelf extends StatefulWidget {
  const PipelineShelf({
    super.key,
    required this.schemes,
    required this.cast,
    required this.onChoose,
    required this.onRename,
    required this.onRemove,
    required this.onExport,
  });

  static const height = 132.0;

  final List<SavedPipeline> schemes;

  /// The cards the machine has, so a scheme's picture draws the characters
  /// it names rather than boxes with nothing in them.
  final List<Character> cast;

  final ValueChanged<String> onChoose;
  final void Function(String id, String name) onRename;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onExport;

  @override
  State<PipelineShelf> createState() => _PipelineShelfState();
}

class _PipelineShelfState extends State<PipelineShelf> {
  /// Folded away until the heading is pressed. The canvas is what the screen
  /// is for; the shelf is asked for now and then.
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The whole heading is the handle, not a lone arrow: there is
        // nothing else on that line to hit by mistake.
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                _ShelfLabel(label: l10n.pipelineSchemes.toUpperCase()),
                const SizedBox(width: 10),
                Text(
                  widget.schemes.isEmpty ? '' : '${widget.schemes.length}',
                  style: const TextStyle(
                    fontFamily: LoreDubFonts.mono,
                    fontSize: 11,
                    color: LoreDubPalette.mutedInk,
                  ),
                ),
                const Spacer(),
                Icon(
                  _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 20,
                  color: LoreDubPalette.mutedInk,
                ),
              ],
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 8),
          if (widget.schemes.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
              child: Text(
                l10n.pipelineSchemesEmpty,
                style: const TextStyle(fontSize: 12, color: LoreDubPalette.mutedInk),
              ),
            )
          else
            SizedBox(
              height: PipelineShelf.height,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: widget.schemes.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _SchemeCard(
                  scheme: widget.schemes[index],
                  cast: widget.cast,
                  onChoose: () => widget.onChoose(widget.schemes[index].id),
                  onRename: (name) => widget.onRename(widget.schemes[index].id, name),
                  onRemove: () => widget.onRemove(widget.schemes[index].id),
                  onExport: () => widget.onExport(widget.schemes[index].id),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// The shelf's own heading, in the vocabulary the screens' module labels use.
class _ShelfLabel extends StatelessWidget {
  const _ShelfLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 28,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: LoreDubPalette.orange,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: LoreDubPalette.ink),
        ),
        child: const Text(
          '02',
          style: TextStyle(
            fontFamily: LoreDubFonts.mono,
            color: LoreDubPalette.ink,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(width: 9),
      Text(
        label,
        style: const TextStyle(
          fontFamily: LoreDubFonts.mono,
          fontSize: 11,
          letterSpacing: 1.4,
          color: LoreDubPalette.ink,
        ),
      ),
    ],
  );
}

class _SchemeCard extends StatelessWidget {
  const _SchemeCard({
    required this.scheme,
    required this.cast,
    required this.onChoose,
    required this.onRename,
    required this.onRemove,
    required this.onExport,
  });

  static const width = 208.0;

  final SavedPipeline scheme;
  final List<Character> cast;
  final VoidCallback onChoose;
  final ValueChanged<String> onRename;
  final VoidCallback onRemove;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final graph = buildPipelineGraph(
      settings: AppSettings(
        captureMode: scheme.captureMode,
        captureRouted: scheme.captureRouted,
        castRouted: scheme.castRouted,
      ),
      characters: cast,
      layout: scheme.layout,
    );
    return SizedBox(
      width: width,
      child: Material(
        color: LoreDubPalette.panel,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: LoreDubPalette.outline),
        ),
        child: InkWell(
          onTap: onChoose,
          child: Tooltip(
            message: l10n.pipelineSchemeApply,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: CustomPaint(painter: _SchemePainter(graph)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 4, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              scheme.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: LoreDubFonts.display,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _note(l10n),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: LoreDubFonts.mono,
                                fontSize: 10,
                                color: LoreDubPalette.mutedInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _SchemeMenu(
                        scheme: scheme,
                        onRename: onRename,
                        onRemove: onRemove,
                        onExport: onExport,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// What the scheme is, in one line: the route it takes and how many cards
  /// it puts on the canvas.
  String _note(AppLocalizations l10n) {
    final route = !scheme.captureRouted
        ? l10n.pipelineSchemeUnrouted
        : scheme.captureMode == CaptureMode.ocr
        ? l10n.pipelineSchemeOcr
        : l10n.pipelineSchemeAudio;
    if (scheme.layout.cast.isEmpty) return route;
    return '$route · ${l10n.pipelineSchemeCast(scheme.layout.cast.length)}';
  }
}

class _SchemeMenu extends StatelessWidget {
  const _SchemeMenu({
    required this.scheme,
    required this.onRename,
    required this.onRemove,
    required this.onExport,
  });

  final SavedPipeline scheme;
  final ValueChanged<String> onRename;
  final VoidCallback onRemove;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      tooltip: '',
      icon: const Icon(Icons.more_vert_rounded, size: 18),
      style: IconButton.styleFrom(
        minimumSize: const Size(30, 30),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onSelected: (choice) => switch (choice) {
        'rename' => _rename(context, l10n),
        'export' => onExport(),
        _ => onRemove(),
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'rename', child: Text(l10n.pipelineSchemeRename)),
        PopupMenuItem(value: 'export', child: Text(l10n.pipelineSchemeExport)),
        PopupMenuItem(value: 'delete', child: Text(l10n.pipelineSchemeDelete)),
      ],
    );
  }

  Future<void> _rename(BuildContext context, AppLocalizations l10n) async {
    final name = await askForName(
      context,
      title: l10n.pipelineSchemeName,
      action: l10n.pipelineSchemeRename,
      initial: scheme.name,
    );
    if (name != null) onRename(name);
  }
}

/// Asks for a name in a dialog, and answers with it or with nothing.
Future<String?> askForName(
  BuildContext context, {
  required String title,
  required String action,
  String initial = '',
}) async {
  final name = await showDialog<String>(
    context: context,
    builder: (context) => _NameDialog(title: title, action: action, initial: initial),
  );
  return name == null || name.isEmpty ? null : name;
}

/// The dialog that asks for a name.
///
/// It owns the field's controller rather than being handed one: a dialog is
/// still on screen while it fades out, and a controller let go of the moment
/// the answer came back is one the field is still reading from — which ends
/// in a torn-down piece of the tree being asked what it depends on.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.action, required this.initial});

  final String title;
  final String action;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _field = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _answer([String? value]) => Navigator.of(context).pop((value ?? _field.text).trim());

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(controller: _field, autofocus: true, onSubmitted: _answer),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(AppLocalizations.of(context).pipelineSchemeCancel),
      ),
      FilledButton(onPressed: _answer, child: Text(widget.action)),
    ],
  );
}

/// The scheme at the size of a thumbnail: every node a box where it stands,
/// every link a line between them, fitted into whatever room the card has.
class _SchemePainter extends CustomPainter {
  const _SchemePainter(this.graph);

  final PipelineGraph graph;

  @override
  void paint(Canvas canvas, Size size) {
    if (graph.nodes.isEmpty) return;
    final spread = _bounds();
    if (spread.width <= 0 || spread.height <= 0) return;

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

  /// The rectangle every node of the scheme fits inside, cards and all.
  Rect _bounds() {
    var left = double.infinity;
    var top = double.infinity;
    var right = -double.infinity;
    var bottom = -double.infinity;
    for (final node in graph.nodes) {
      final card = NodeMetrics.sizeOf(node.kind);
      left = math.min(left, node.position.x);
      top = math.min(top, node.position.y);
      right = math.max(right, node.position.x + card.width);
      bottom = math.max(bottom, node.position.y + card.height);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// The links, as straight lines rather than the canvas's curves: at a
  /// thumb's width a curve and a line look the same.
  void _drawWires(Canvas canvas, Offset Function(GraphPoint point) place) {
    final wire = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = LoreDubPalette.mutedInk;
    for (final link in graph.links) {
      final from = graph.node(link.from.nodeId);
      final to = graph.node(link.to.nodeId);
      if (from == null || to == null) continue;
      final start = NodeMetrics.portAt(from, link.from.socket);
      final end = NodeMetrics.portAt(to, link.to.socket);
      canvas.drawLine(
        place(GraphPoint(start.dx, start.dy)),
        place(GraphPoint(end.dx, end.dy)),
        wire
          ..color = link.signal == PipelineSignal.voice
              ? LoreDubPalette.mutedInk
              : LoreDubPalette.orange,
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
              ? LoreDubPalette.panel
              : LoreDubPalette.raised,
      );
      canvas.drawRRect(
        rounded,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = node.unrouted ? LoreDubPalette.outline : LoreDubPalette.ink,
      );
    }
  }

  @override
  bool shouldRepaint(_SchemePainter old) => old.graph != graph;
}
