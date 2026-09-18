// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../theme.dart';

/// The colours of a model tile, decided once from where the model stands.
class ModelTileLook {
  const ModelTileLook({
    required this.face,
    required this.ink,
    required this.edge,
    required this.edgeWidth,
  });

  /// A tile arriving or chosen wears the orange edge; one in use is dark;
  /// orange is the one colour that reads on the light face and on the dark
  /// fill rising behind the words, so a download writes in it.
  factory ModelTileLook.of({
    required bool downloading,
    required bool inUse,
    required bool marked,
    required bool hovered,
  }) {
    final edged = marked || downloading;
    return ModelTileLook(
      face: inUse ? LoreDubPalette.graphite : LoreDubPalette.panel,
      ink: _ink(downloading: downloading, inUse: inUse),
      edge: _edge(edged: edged, hovered: hovered),
      edgeWidth: edged ? 2 : 1,
    );
  }

  static Color _edge({required bool edged, required bool hovered}) {
    if (edged) return LoreDubPalette.orange;
    return hovered ? LoreDubPalette.ink : LoreDubPalette.outline;
  }

  static Color _ink({required bool downloading, required bool inUse}) {
    if (downloading) return LoreDubPalette.orange;
    return inUse ? LoreDubPalette.raised : LoreDubPalette.ink;
  }

  final Color face;
  final Color ink;
  final Color edge;
  final double edgeWidth;
}
