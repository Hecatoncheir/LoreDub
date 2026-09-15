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
  );
}

/// The same interface, in the colours a node is drawn in.
///
/// The node panel on the graph screen is a card of the scheme rather than a
/// page beside it, so it is drawn the way the plain nodes are: the raised
/// paper for the face of it, the panel grey for its head and for the fields
/// sunk into it. Everything else — the shapes, the faces, the orange — is
/// the theme's own.
ThemeData buildLoreDubPanelTheme() {
  final base = buildLoreDubTheme();
  const fieldBorder = OutlineInputBorder(
    borderSide: BorderSide(color: LoreDubPalette.outline),
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );

  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(surface: LoreDubPalette.raised),
    // What a dropdown opens onto.
    canvasColor: LoreDubPalette.raised,
    cardTheme: base.cardTheme.copyWith(color: LoreDubPalette.raised),
    // Sunk into the face of the panel rather than raised out of it: on the
    // paper colour a field filled with the same is an outline and nothing
    // else.
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      fillColor: LoreDubPalette.panel,
      border: fieldBorder,
      enabledBorder: fieldBorder,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        foregroundColor: const WidgetStatePropertyAll(LoreDubPalette.ink),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? LoreDubPalette.orange : LoreDubPalette.panel,
        ),
        side: const WidgetStatePropertyAll(BorderSide(color: LoreDubPalette.graphite)),
      ),
    ),
  );
}
