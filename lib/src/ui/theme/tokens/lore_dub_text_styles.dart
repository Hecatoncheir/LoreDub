// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import 'lore_dub_colors.dart';
import 'palette.dart';

/// The lettering LoreDub uses that Material has no name for: the markings
/// of an instrument. Everything else -- headings, running text, labels --
/// is the `TextTheme` of the theme itself.
///
/// Built from [LoreDubColors], so a second face carries its own.
@immutable
class LoreDubTextStyles extends ThemeExtension<LoreDubTextStyles> {
  const LoreDubTextStyles({
    required this.moduleNumber,
    required this.moduleLabel,
    required this.cardTitle,
    required this.monoCaption,
    required this.monoMarking,
  });

  /// The roles as [colors] paints them.
  factory LoreDubTextStyles.from(LoreDubColors colors) => LoreDubTextStyles(
    moduleNumber: TextStyle(
      fontFamily: LoreDubFonts.mono,
      color: colors.onAccent,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    ),
    moduleLabel: TextStyle(
      fontFamily: LoreDubFonts.mono,
      color: colors.ink,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
    ),
    cardTitle: TextStyle(
      fontFamily: LoreDubFonts.display,
      color: colors.ink,
      fontSize: 17,
      fontWeight: FontWeight.w700,
    ),
    monoCaption: TextStyle(
      fontFamily: LoreDubFonts.mono,
      color: colors.mutedInk,
      fontSize: 11,
    ),
    monoMarking: TextStyle(
      fontFamily: LoreDubFonts.mono,
      color: colors.mutedInk,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    ),
  );

  /// The numeral an area is known by, on the orange.
  final TextStyle moduleNumber;

  /// The name beside it, in capitals.
  final TextStyle moduleLabel;

  /// What a tile or a node is called.
  final TextStyle cardTitle;

  /// A measured thing said under something else: seconds, megabytes, a
  /// count.
  final TextStyle monoCaption;

  /// A state said in capitals -- ЗВУК ИГРЫ, НЕ ПОДКЛЮЧЕНО -- where the
  /// letters are read as a marking rather than as a sentence.
  final TextStyle monoMarking;

  @override
  LoreDubTextStyles copyWith({
    TextStyle? moduleNumber,
    TextStyle? moduleLabel,
    TextStyle? cardTitle,
    TextStyle? monoCaption,
    TextStyle? monoMarking,
  }) => LoreDubTextStyles(
    moduleNumber: moduleNumber ?? this.moduleNumber,
    moduleLabel: moduleLabel ?? this.moduleLabel,
    cardTitle: cardTitle ?? this.cardTitle,
    monoCaption: monoCaption ?? this.monoCaption,
    monoMarking: monoMarking ?? this.monoMarking,
  );

  @override
  LoreDubTextStyles lerp(LoreDubTextStyles? other, double t) {
    if (other == null) return this;
    return LoreDubTextStyles(
      moduleNumber: TextStyle.lerp(moduleNumber, other.moduleNumber, t)!,
      moduleLabel: TextStyle.lerp(moduleLabel, other.moduleLabel, t)!,
      cardTitle: TextStyle.lerp(cardTitle, other.cardTitle, t)!,
      monoCaption: TextStyle.lerp(monoCaption, other.monoCaption, t)!,
      monoMarking: TextStyle.lerp(monoMarking, other.monoMarking, t)!,
    );
  }
}
