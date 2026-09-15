// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import 'dashboard/node_paint.dart';

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

/// The same interface, in the colours [paint] draws a node in.
///
/// The panel that opens on a node is that node's panel: it takes the face
/// the node carries, so choosing the orange output opens an orange panel and
/// choosing a card of the cast opens a dark one. Everything else — the
/// shapes, the faces, the spacing — is the theme's own, so what stands in
/// the panel is the same interface in another colour rather than a second
/// one.
ThemeData buildLoreDubPanelTheme(NodePaint paint) {
  final base = buildLoreDubTheme();
  const controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );
  final fieldBorder = OutlineInputBorder(
    borderSide: BorderSide(color: paint.rule),
    borderRadius: const BorderRadius.all(Radius.circular(8)),
  );

  return base.copyWith(
    brightness: paint.dark ? Brightness.dark : Brightness.light,
    colorScheme: base.colorScheme.copyWith(
      brightness: paint.dark ? Brightness.dark : Brightness.light,
      primary: paint.chosen,
      onPrimary: paint.onChosen,
      surface: paint.body,
      onSurface: paint.ink,
      outline: paint.rule,
    ),
    // What a dropdown opens onto.
    canvasColor: paint.sunk,
    textTheme: base.textTheme
        .apply(bodyColor: paint.ink, displayColor: paint.ink)
        // What a label or a note is said in, which every one of them reads
        // rather than naming a colour of its own.
        .copyWith(bodySmall: base.textTheme.bodySmall?.copyWith(color: paint.muted)),
    dividerColor: paint.rule,
    cardTheme: base.cardTheme.copyWith(
      color: paint.sunk,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: paint.rule),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      // Sunk into the face of the panel rather than raised out of it: filled
      // with the face's own colour a field is an outline and nothing else.
      fillColor: paint.sunk,
      labelStyle: TextStyle(color: paint.muted),
      helperStyle: TextStyle(color: paint.muted),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: paint.chosen, width: 2),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: paint.onChosen,
        backgroundColor: paint.chosen,
        disabledBackgroundColor: paint.sunk,
        disabledForegroundColor: paint.muted,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: controlShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: paint.ink,
        minimumSize: const Size(48, 48),
        side: BorderSide(color: paint.rule),
        shape: controlShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: paint.chosen,
        minimumSize: const Size(44, 44),
        shape: controlShape,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: paint.ink,
        minimumSize: const Size(48, 48),
        shape: controlShape,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? paint.onChosen : paint.ink,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? paint.chosen : paint.sunk,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: paint.rule)),
      ),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: paint.chosen,
      inactiveTrackColor: paint.rule,
      thumbColor: paint.chosen,
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (!states.contains(WidgetState.selected)) return paint.sunk;
        return states.contains(WidgetState.disabled)
            ? paint.chosen.withValues(alpha: 0.45)
            : paint.chosen;
      }),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (!states.contains(WidgetState.selected)) return paint.muted;
        return states.contains(WidgetState.disabled) ? paint.body : paint.onChosen;
      }),
      trackOutlineColor: WidgetStatePropertyAll(paint.rule),
      overlayColor: WidgetStatePropertyAll(paint.chosen.withValues(alpha: 0.12)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: paint.chosen,
      linearTrackColor: paint.rule,
    ),
    focusColor: paint.chosen.withValues(alpha: 0.22),
  );
}
