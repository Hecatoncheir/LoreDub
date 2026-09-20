// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../theme.dart';

/// The edge a tile of this interface wears: the accent where the tile is
/// marked -- chosen, in use, or arriving -- the ink under the pointer, and
/// the quiet outline otherwise; two pixels where it is marked and one where
/// it is not.
///
/// Three screens draw a tile in a vocabulary of their own -- a model, a
/// stage on a device, a card of the cast -- and the edge was the one part
/// of it they said word for word. It is the mark that says which tile the
/// player has landed on and which one the pipeline is using, so the three
/// have to agree about it.
@immutable
class TileEdge {
  const TileEdge({required this.color, required this.width});

  /// [marked] wears the accent, [hovered] the ink. [quiet] fades the plain
  /// outline, for a tile the machine has ruled out: it is still a tile, and
  /// still has an edge, but nothing will happen to it.
  factory TileEdge.of(
    LoreDubColors colors, {
    required bool marked,
    required bool hovered,
    bool quiet = false,
  }) {
    if (marked) return TileEdge(color: colors.accent, width: 2);
    if (hovered) return TileEdge(color: colors.ink, width: 1);
    return TileEdge(color: colors.outline.withValues(alpha: quiet ? 0.5 : 1), width: 1);
  }

  final Color color;
  final double width;

  BorderSide get side => BorderSide(color: color, width: width);

  /// The tile's outline at [radius]. The corner is the screen's own: a
  /// model and a card of the cast are 12, a cell of the device table 10.
  RoundedRectangleBorder shaped(double radius) => RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(radius)),
    side: side,
  );

  @override
  bool operator ==(Object other) =>
      other is TileEdge && other.color == color && other.width == width;

  @override
  int get hashCode => Object.hash(color, width);
}
