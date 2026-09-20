// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../theme.dart';
import 'node_paint.dart';

/// The panel theme of each face, kept: there are four faces, the panel is
/// rebuilt on every frame of a drag behind it, and a `ThemeData` of a
/// hundred and seventy lines is not worth building sixty times a second.
final _panelThemes = <NodePaint, ThemeData>{};

/// The window's widgets in the face of one node, for the panel that stands
/// over the canvas.
ThemeData buildLoreDubPanelTheme(NodePaint paint) => _panelThemes[paint] ??= _panelTheme(paint);

ThemeData _panelTheme(NodePaint paint) {
  final base = buildLoreDubTheme();
  final colors = _colorsOf(paint);
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
      // What Material raises out of a surface of its own accord: the menu a
      // dropdown opens, the sheet a dialog stands on. Left at the house
      // theme's they came out paper-coloured under writing meant for the
      // face of this panel, which on the orange nodes is barely there.
      surfaceContainerLowest: paint.body,
      surfaceContainerLow: paint.body,
      surfaceContainer: paint.sunk,
      surfaceContainerHigh: paint.sunk,
      surfaceContainerHighest: paint.sunk,
      surfaceTint: paint.body,
      onSurfaceVariant: paint.muted,
      secondaryContainer: paint.sunk,
      onSecondaryContainer: paint.ink,
      outline: paint.rule,
      outlineVariant: paint.rule,
      // What Material turns over for a tooltip or a value bubble.
      inverseSurface: paint.sunk,
      onInverseSurface: paint.ink,
    ),
    // What a dropdown opens onto.
    canvasColor: paint.sunk,
    textTheme: base.textTheme
        .apply(bodyColor: paint.ink, displayColor: paint.ink)
        // What a label or a note is said in, which every one of them reads
        // rather than naming a colour of its own.
        .copyWith(bodySmall: base.textTheme.bodySmall?.copyWith(color: paint.muted)),
    dividerColor: paint.rule,
    // The same roles in the face of this node, so a widget standing in the
    // panel is the widget of the window in another colour.
    extensions: [colors, LoreDubTextStyles.from(colors)],
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
      // A focused field floats its label in the colour that marks what is
      // chosen, which on the orange nodes is the ink: the name of the field
      // then sat in the orange rather than on it.
      floatingLabelStyle: TextStyle(color: paint.ink),
      helperStyle: TextStyle(color: paint.muted),
      hintStyle: TextStyle(color: paint.muted),
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
    // The list a dropdown opens: its own surface, and the entries written in
    // the panel's ink rather than in the theme above it.
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: TextStyle(color: paint.ink),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(paint.sunk),
        surfaceTintColor: WidgetStatePropertyAll(paint.sunk),
        side: WidgetStatePropertyAll(BorderSide(color: paint.rule)),
      ),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(paint.ink),
        overlayColor: WidgetStatePropertyAll(paint.chosen.withValues(alpha: 0.12)),
      ),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: paint.chosen,
      inactiveTrackColor: paint.rule,
      thumbColor: paint.chosen,
      // The number that rises over the thumb while it is dragged. Left to
      // Material it came out of the theme above this panel, which on the
      // orange nodes put pale text on a pale bubble.
      valueIndicatorColor: paint.chosen,
      valueIndicatorTextStyle: TextStyle(color: paint.onChosen, fontWeight: FontWeight.w700),
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

/// A node's face as the roles the widgets of the panel read.
LoreDubColors _colorsOf(NodePaint paint) => LoreDubColors.light.copyWith(
  canvas: paint.body,
  panel: paint.body,
  raised: paint.sunk,
  ink: paint.ink,
  mutedInk: paint.muted,
  outline: paint.rule,
  accent: paint.chosen,
  accentStrong: paint.chosen,
  onAccent: paint.onChosen,
);
