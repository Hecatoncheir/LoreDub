// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import 'theme/tokens/lore_dub_colors.dart';
import 'theme/tokens/lore_dub_text_styles.dart';
import 'theme/tokens/palette.dart';

export 'theme/theme_context.dart';
export 'theme/tokens/lore_dub_colors.dart';
export 'theme/tokens/lore_dub_text_styles.dart';
export 'theme/tokens/palette.dart';

final _lightStyles = LoreDubTextStyles.from(LoreDubColors.light);

ThemeData buildLoreDubTheme() {
  const scheme = ColorScheme.light(
    primary: LoreDubPalette.orange,
    onPrimary: LoreDubPalette.ink,
    secondary: LoreDubPalette.graphite,
    onSecondary: Colors.white,
    surface: LoreDubPalette.panel,
    onSurface: LoreDubPalette.ink,
    error: LoreDubPalette.error,
    onError: Colors.white,
    outline: LoreDubPalette.outline,
  );
  const controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: LoreDubPalette.canvas,
    fontFamily: LoreDubFonts.body,
    // Nunito Sans carries no arrow, and the pipeline is written with one in
    // more than one place. The monospaced face is bundled and has it, so the
    // glyph is drawn from something we ship rather than from whatever font
    // Windows happens to substitute.
    fontFamilyFallback: const [LoreDubFonts.mono],
    visualDensity: VisualDensity.standard,
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontFamily: LoreDubFonts.display,
        color: LoreDubPalette.ink,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: TextStyle(
        fontFamily: LoreDubFonts.display,
        color: LoreDubPalette.ink,
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: LoreDubPalette.ink,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: TextStyle(
        color: LoreDubPalette.ink,
        fontSize: 14,
        height: 1.45,
      ),
      labelLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.1),
      // The three Material leaves out of this theme, which is why a note
      // used to be written where it stood: the quiet half of the text, in
      // the two sizes the interface says it in, and the smaller title a
      // field or a row is headed with.
      titleSmall: TextStyle(
        color: LoreDubPalette.ink,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      bodySmall: TextStyle(color: LoreDubPalette.mutedInk, fontSize: 13),
      labelSmall: TextStyle(color: LoreDubPalette.mutedInk, fontSize: 12),
    ),
    dividerColor: LoreDubPalette.outline,
    cardTheme: const CardThemeData(
      color: LoreDubPalette.panel,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: LoreDubPalette.outline),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: LoreDubPalette.ink,
        backgroundColor: LoreDubPalette.orange,
        disabledBackgroundColor: LoreDubPalette.outline,
        disabledForegroundColor: LoreDubPalette.mutedInk,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: controlShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: LoreDubPalette.ink,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: LoreDubPalette.graphite),
        shape: controlShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: LoreDubPalette.orangeDark,
        minimumSize: const Size(44, 44),
        shape: controlShape,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: LoreDubPalette.ink,
        minimumSize: const Size(48, 48),
        shape: controlShape,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: LoreDubPalette.raised,
      labelStyle: TextStyle(color: LoreDubPalette.mutedInk),
      helperStyle: TextStyle(color: LoreDubPalette.mutedInk),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: LoreDubPalette.outline),
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: LoreDubPalette.outline),
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: LoreDubPalette.orange, width: 2),
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: LoreDubPalette.orange,
      inactiveTrackColor: LoreDubPalette.outline,
      thumbColor: LoreDubPalette.orange,
      overlayColor: Color(0x22FF4A16),
      showValueIndicator: ShowValueIndicator.onDrag,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        foregroundColor: const WidgetStatePropertyAll(LoreDubPalette.ink),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? LoreDubPalette.orange : LoreDubPalette.raised,
        ),
        side: const WidgetStatePropertyAll(
          BorderSide(color: LoreDubPalette.graphite),
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      // The on state is spelled out for every interaction: a switch stays
      // disabled while the pipeline runs, where the default styling washes it
      // out until it reads as off, and hovering it would otherwise tint the
      // thumb with primaryContainer until it vanishes into the orange track.
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (!states.contains(WidgetState.selected)) return null;
        return states.contains(WidgetState.disabled)
            ? LoreDubPalette.orange.withValues(alpha: 0.45)
            : LoreDubPalette.orange;
      }),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (!states.contains(WidgetState.selected)) return null;
        return states.contains(WidgetState.disabled) ? LoreDubPalette.raised : LoreDubPalette.ink;
      }),
      overlayColor: WidgetStatePropertyAll(LoreDubPalette.orange.withValues(alpha: 0.12)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: LoreDubPalette.orange,
      linearTrackColor: LoreDubPalette.outline,
    ),
    focusColor: LoreDubPalette.orange.withValues(alpha: 0.22),
    // LoreDub's own roles, which every widget of ours reads off the
    // context rather than naming a colour by hand.
    extensions: [LoreDubColors.light, _lightStyles],
  );
}

/// The same interface, in the colours [paint] draws a node in.
///
/// The panel that opens on a node is that node's panel: it takes the face
/// the node carries, so choosing the orange output opens an orange panel and
/// choosing a card of the cast opens a dark one. Everything else — the
/// shapes, the faces, the spacing — is the theme's own, so what stands in
/// the panel is the same interface in another colour rather than a second
/// one.
