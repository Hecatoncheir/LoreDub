// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// The shelf of kept schemes: a card each, with a picture of the scheme on
/// it, under the graph's own toolbar.
///
/// The picture is drawn from the scheme itself rather than kept as an image:
/// it is the same nodes and the same links, at the size of a thumbnail, so
/// it can never show a scheme the file no longer holds.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/character.dart';
import '../../../domain/saved_pipeline.dart';
import '../../theme.dart';
import 'shelf_label.dart';
import 'scheme_card.dart';

/// The kept schemes, folded under their heading until it is pressed.
class PipelineShelf extends StatefulWidget {
  const PipelineShelf({
    super.key,
    required this.schemes,
    required this.cast,
    required this.onChoose,
    required this.onReplace,
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

  /// Writes what is on the canvas over the scheme, which keeps its name and
  /// its place on the shelf.
  final ValueChanged<String> onReplace;
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

  /// Held here so the scrollbar and the row it belongs to are the same
  /// scroll: a shelf wider than the window is dragged by either.
  final _shelf = ScrollController();

  @override
  void dispose() {
    _shelf.dispose();
    super.dispose();
  }

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
                ShelfLabel(
                  label: l10n.pipelineSchemes.toUpperCase(),
                  count: widget.schemes.length,
                ),
                const Spacer(),
                Icon(
                  _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 20,
                  color: context.colors.mutedInk,
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
                style: Theme.of(context).textTheme.labelSmall,
              ),
            )
          else
            SizedBox(
              height: PipelineShelf.height,
              // Kept schemes run off the side of the window as soon as there
              // are a few: the bar under them can be dragged, and so can the
              // cards themselves, a mouse being as good as a finger here.
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                    PointerDeviceKind.stylus,
                  },
                  scrollbars: false,
                ),
                child: Scrollbar(
                  controller: _shelf,
                  thumbVisibility: true,
                  child: ListView.separated(
                    controller: _shelf,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: widget.schemes.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => SchemeCard(
                      scheme: widget.schemes[index],
                      cast: widget.cast,
                      onChoose: () => widget.onChoose(widget.schemes[index].id),
                      onReplace: () => widget.onReplace(widget.schemes[index].id),
                      onRename: (name) => widget.onRename(widget.schemes[index].id, name),
                      onRemove: () => widget.onRemove(widget.schemes[index].id),
                      onExport: () => widget.onExport(widget.schemes[index].id),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
