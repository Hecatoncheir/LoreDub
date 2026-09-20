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
  /// [colors] are the roles the tile is drawn in, handed over rather than
  /// read off a context: the look is decided from where the model stands
  /// and knows nothing of the tree it will be drawn in.
  factory ModelTileLook.of({
    required LoreDubColors colors,
    required bool downloading,
    required bool inUse,
    required bool marked,
    required bool hovered,
  }) {
    final edged = marked || downloading;
    return ModelTileLook(
      face: inUse ? colors.deep : colors.panel,
      ink: _ink(colors, downloading: downloading, inUse: inUse),
      edge: _edge(colors, edged: edged, hovered: hovered),
      edgeWidth: edged ? 2 : 1,
    );
  }

  static Color _edge(LoreDubColors colors, {required bool edged, required bool hovered}) {
    if (edged) return colors.accent;
    return hovered ? colors.ink : colors.outline;
  }

  static Color _ink(LoreDubColors colors, {required bool downloading, required bool inUse}) {
    if (downloading) return colors.accent;
    return inUse ? colors.raised : colors.ink;
  }

  final Color face;
  final Color ink;
  final Color edge;
  final double edgeWidth;
}
