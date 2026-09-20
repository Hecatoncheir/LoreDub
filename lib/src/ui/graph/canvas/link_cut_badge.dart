// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../theme.dart';
import 'link_cut.dart';

/// The button that cuts a line, sitting on the middle of the curve it cuts.
class LinkCutBadge extends StatelessWidget {
  const LinkCutBadge({super.key, required this.at, required this.cut, required this.onCut});

  /// The middle of the curve, on the canvas.
  final Offset at;
  final LinkCut cut;
  final VoidCallback onCut;

  static const _size = 30.0;

  @override
  Widget build(BuildContext context) => Positioned(
    left: at.dx - _size / 2,
    top: at.dy - _size / 2,
    width: _size,
    height: _size,
    child: Tooltip(
      // Every kind of line parts with something of its own: the pipeline
      // loses what feeds it, the translator leaves the line or comes back
      // into it, the cast leaves the mix, a card stops being counted among
      // the voices of the game, or one card takes its own part back.
      message: cut.describe(AppLocalizations.of(context)),
      child: Material(
        shape: CircleBorder(side: BorderSide(color: context.colors.deep)),
        color: context.colors.raised,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onCut,
          child: const Icon(Icons.link_off_rounded, size: 16),
        ),
      ),
    ),
  );
}
