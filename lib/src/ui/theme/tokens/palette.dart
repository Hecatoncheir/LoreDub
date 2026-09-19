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
}
