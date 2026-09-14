// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// The shelf of kept schemes: a card each, with a picture of the scheme on
/// it, under the graph's own toolbar.
///
/// The picture is drawn from the scheme itself rather than kept as an image:
/// it is the same nodes and the same links, at the size of a thumbnail, so
/// it can never show a scheme the file no longer holds.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../../domain/character.dart';
import '../../domain/pipeline_graph.dart';
import '../../domain/saved_pipeline.dart';
import '../theme.dart';
import 'pipeline_canvas.dart' show NodeMetrics;

class PipelineShelf extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (schemes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
        child: Text(
          l10n.pipelineSchemesEmpty,
          style: const TextStyle(fontSize: 12, color: LoreDubPalette.mutedInk),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: schemes.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _SchemeCard(
          scheme: schemes[index],
          cast: cast,
          onChoose: () => onChoose(schemes[index].id),
          onRename: (name) => onRename(schemes[index].id, name),
          onRemove: () => onRemove(schemes[index].id),
          onExport: () => onExport(schemes[index].id),
        ),
      ),
    );
  }
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
  final field = TextEditingController(text: initial);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: field,
        autofocus: true,
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).pipelineSchemeCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(field.text.trim()),
          child: Text(action),
        ),
      ],
    ),
  );
  field.dispose();
  return name == null || name.isEmpty ? null : name;
}

/// The scheme at the size of a thumbnail: every node a box where it stands,
/// every link a line between them, fitted into whatever room the card has.
class _SchemePainter extends CustomPainter {
  const _SchemePainter(this.graph);

  final PipelineGraph graph;

  @override
  void paint(Canvas canvas, Size size) {
    if (graph.nodes.isEmpty) return;
    var left = double.infinity;
    var top = double.infinity;
    var right = -double.infinity;
    var bottom = -double.infinity;
    for (final node in graph.nodes) {
      final card = NodeMetrics.sizeOf(node.kind);
      left = left < node.position.x ? left : node.position.x;
      top = top < node.position.y ? top : node.position.y;
      final edge = node.position.x + card.width;
      final foot = node.position.y + card.height;
      right = right > edge ? right : edge;
      bottom = bottom > foot ? bottom : foot;
    }
    final spread = Size(right - left, bottom - top);
    if (spread.width <= 0 || spread.height <= 0) return;
    final scale = (size.width / spread.width) < (size.height / spread.height)
        ? size.width / spread.width
        : size.height / spread.height;
    // Put in the middle of what room there is, so a wide scheme and a tall
    // one both sit in the card rather than hugging a corner of it.
    final offset = Offset(
      (size.width - spread.width * scale) / 2,
      (size.height - spread.height * scale) / 2,
    );

    Offset place(GraphPoint point) => Offset(
      (point.x - left) * scale + offset.dx,
      (point.y - top) * scale + offset.dy,
    );

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

    for (final node in graph.nodes) {
      final card = NodeMetrics.sizeOf(node.kind);
      final box = Rect.fromPoints(
        place(node.position),
        place(node.position.translate(card.width, card.height)),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(2)),
        Paint()
          ..color = node.unrouted
              ? LoreDubPalette.raised
              : node.kind == PipelineNodeKind.character
              ? LoreDubPalette.panel
              : LoreDubPalette.raised,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(2)),
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
