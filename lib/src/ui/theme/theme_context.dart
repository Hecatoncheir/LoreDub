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
/// the node panel's -- so they are there wherever a widget of ours is. A
/// widget standing under somebody else's theme -- a test that builds one of
/// them alone, a Material default -- falls back to the light roles rather
/// than throwing: it is a widget of this application whatever it was hung
/// under, and it has a face of its own to be drawn in.
extension LoreDubThemeContext on BuildContext {
  LoreDubColors get colors => Theme.of(this).extension<LoreDubColors>() ?? LoreDubColors.light;

  LoreDubTextStyles get textStyles => Theme.of(this).extension<LoreDubTextStyles>() ?? _lightStyles;
}

final _lightStyles = LoreDubTextStyles.from(LoreDubColors.light);
