// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../theme.dart';
import 'node_paint.dart';

/// The panel theme of each face, kept: there are four faces, the panel is
/// rebuilt on every frame of a drag behind it, and a `ThemeData` of this
/// size is not worth building sixty times a second.
final _panelThemes = <NodePaint, ThemeData>{};

/// The window's widgets in the face of one node, for the panel that stands
/// over the canvas.
///
/// It is `AppTheme.build` and nothing else: the panel is the same interface
/// in another colour rather than a second one, so all it takes is the face
/// read as roles.
ThemeData buildLoreDubPanelTheme(NodePaint paint) => _panelThemes[paint] ??= AppTheme.build(
  _colorsOf(paint),
  paint.dark ? Brightness.dark : Brightness.light,
);

/// A node's face as the roles the widgets of the panel read.
///
/// A face carries two greys where the window carries three, so the sunk one
/// stands for the panel a card is, the fill a field is sunk into and the
/// dark a chosen chip stands on, while the body stands for the ground under
/// them. The window's stronger outline -- the graphite a pressable control
/// is edged with -- has no counterpart on a face at all: there the rule
/// does that work too.
LoreDubColors _colorsOf(NodePaint paint) => LoreDubColors.light.copyWith(
  canvas: paint.body,
  panel: paint.sunk,
  raised: paint.sunk,
  ink: paint.ink,
  mutedInk: paint.muted,
  outline: paint.rule,
  strongOutline: paint.rule,
  deep: paint.sunk,
  onDeep: paint.ink,
  accent: paint.chosen,
  accentStrong: paint.chosen,
  onAccent: paint.onChosen,
);
