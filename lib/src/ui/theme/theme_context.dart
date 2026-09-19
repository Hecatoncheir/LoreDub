// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import 'tokens/lore_dub_colors.dart';
import 'tokens/lore_dub_text_styles.dart';

/// How a widget reaches LoreDub's own roles: `context.colors.mutedInk`
/// rather than `LoreDubPalette.mutedInk`, so the face it stands on decides
/// what it is painted in.
///
/// Both are put on every theme this application builds -- the window's and
/// the node panel's -- so they are there wherever a widget of ours is.
extension LoreDubThemeContext on BuildContext {
  LoreDubColors get colors => Theme.of(this).extension<LoreDubColors>()!;

  LoreDubTextStyles get textStyles => Theme.of(this).extension<LoreDubTextStyles>()!;
}
