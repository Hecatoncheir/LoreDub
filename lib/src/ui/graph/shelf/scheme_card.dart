// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/character.dart';
import '../../../domain/saved_pipeline.dart';
import '../../theme.dart';
import 'scheme_menu.dart';
import 'scheme_painter.dart';

/// One kept scheme on the shelf: its picture, its name, what it holds, and
/// the menu of what can be done to it. A press puts it on the canvas.
class SchemeCard extends StatelessWidget {
  const SchemeCard({
    super.key,
    required this.scheme,
    required this.cast,
    required this.onChoose,
    required this.onReplace,
    required this.onRename,
    required this.onRemove,
    required this.onExport,
  });

  static const width = 208.0;

  final SavedPipeline scheme;
  final List<Character> cast;
  final VoidCallback onChoose;
  final VoidCallback onReplace;
  final ValueChanged<String> onRename;
  final VoidCallback onRemove;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                    child: CustomPaint(
                      painter: SchemePainter(scheme: scheme, cast: cast),
                    ),
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
                      SchemeMenu(
                        scheme: scheme,
                        onReplace: onReplace,
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

  /// What the scheme is, in one line: whether the way in is drawn and how
  /// many cards it puts on the canvas.
  String _note(AppLocalizations l10n) {
    final route = scheme.captureRouted ? l10n.pipelineSchemeAudio : l10n.pipelineSchemeUnrouted;
    if (scheme.layout.cast.isEmpty) return route;
    return '$route · ${l10n.pipelineSchemeCast(scheme.layout.cast.length)}';
  }
}
