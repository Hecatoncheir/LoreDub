// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

/// Nunito carries the headings, its wider sibling sets the running text, and
/// JetBrains Mono is reserved for the instrument markings — module numbers,
/// state labels and measured times — which is where the icon's industrial
/// character comes from.
abstract final class LoreDubFonts {
  static const display = 'Nunito';
  static const body = 'Nunito Sans';
  static const mono = 'JetBrains Mono';
}

/// How large a control is to the pointer, in logical pixels.
///
/// [comfortable] is what `docs/UI_DESIGN.md` promises, and what the Material
/// buttons give by themselves. The other three are the icon buttons packed
/// where that promise is not kept -- a tile's action band, a menu on a card
/// of the shelf, the cross on a chip or on a card of the canvas -- and are
/// named so that they can be found and grown together rather than one
/// number at a time.
abstract final class LoreDubTargets {
  static const comfortable = 44.0;

  /// The action band of a model or character tile, and a card's menu.
  static const dense = 34.0;

  /// The menu on a scheme of the shelf.
  static const compact = 30.0;

  /// The cross that takes a chip out of a pack or a card off the canvas.
  static const cross = 26.0;
}

abstract final class LoreDubPalette {
  static const ink = Color(0xFF171717);
  static const graphite = Color(0xFF292927);
  static const mutedInk = Color(0xFF65645F);
  static const canvas = Color(0xFFD4D1CA);
  static const panel = Color(0xFFE9E6DF);
  static const raised = Color(0xFFF7F5F0);
  static const outline = Color(0xFF9D9A93);
  static const orange = Color(0xFFFF4A16);
  static const orangeDark = Color(0xFFC92F00);
  static const success = Color(0xFF277A52);
  static const warning = Color(0xFF9A5A00);
  static const error = Color(0xFFB42318);

  /// Turned over. The dark interface is the light one inside out, and it
  /// starts from the face a card of the cast is already drawn in: the ink
  /// is the ground, the graphite is what stands on it, and the cream a
  /// dark node is written in becomes the text of the whole window.
  ///
  /// Only what the light set has no answer for is named here. The third
  /// step up from the ground, the hairline between them, and the states,
  /// which on the ink are too dark to read at the values the paper needs.
  static const raisedDark = Color(0xFF3A3A36);
  static const outlineDark = Color(0xFF5E5D57);
  static const mutedInkDark = Color(0xFFB2B1AD);
  static const orangeLight = Color(0xFFFF7A4F);
  static const successLight = Color(0xFF4FB183);
  static const warningLight = Color(0xFFD79A3C);
  static const errorLight = Color(0xFFE5675C);
}
