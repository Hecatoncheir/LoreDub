// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../common/hover_grow.dart';
import 'model_action.dart';
import 'model_tile_body.dart';
import 'model_tile_look.dart';
import 'model_tile_part.dart';

/// A model, or a pair of them, drawn in the Whisper bars' vocabulary:
/// light while missing, a cloud with a tick once downloaded, graphite with
/// an orange edge in use, filling from the bottom with a ring while it
/// downloads, its buttons always at its foot.
class ModelTile extends StatelessWidget {
  const ModelTile({
    super.key,
    required this.title,
    required this.parts,
    required this.progress,
    required this.paused,
    required this.installed,
    required this.inUse,
    required this.marked,
    required this.tooltip,
    required this.onTap,
    required this.actions,
  });

  final String title;
  final List<ModelTilePart> parts;
  final double? progress;
  final bool paused;
  final bool installed;

  /// Downloaded and in use: the dark face.
  final bool inUse;

  /// Chosen, downloaded or not: the orange edge.
  final bool marked;
  final String tooltip;
  final VoidCallback? onTap;
  final List<ModelAction> actions;

  @override
  Widget build(BuildContext context) => HoverGrow(
    alignment: Alignment.center,
    scale: 1.03,
    builder: (context, hovered) {
      final look = ModelTileLook.of(
        downloading: progress != null,
        inUse: inUse,
        marked: marked,
        hovered: hovered,
      );
      return Semantics(
        button: onTap != null,
        selected: marked,
        label: title,
        child: Material(
          color: look.face,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            side: BorderSide(color: look.edge, width: look.edgeWidth),
          ),
          child: InkWell(
            onTap: onTap,
            child: ModelTileBody(
              title: title,
              parts: parts,
              progress: progress,
              paused: paused,
              installed: installed,
              inUse: inUse,
              ink: look.ink,
              tooltip: tooltip,
              actions: actions,
            ),
          ),
        ),
      );
    },
  );
}
