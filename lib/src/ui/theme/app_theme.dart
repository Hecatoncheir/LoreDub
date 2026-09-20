// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import 'tokens/lore_dub_colors.dart';
import 'tokens/lore_dub_text_styles.dart';
import 'tokens/palette.dart';

/// LoreDub's interface, in whatever colours it is handed.
///
/// One function rather than one per surface: the window and the panel that
/// opens on a node of the scheme are the same interface — the same shapes,
/// the same sizes, the same lettering — and differ only in what they are
/// painted with. So the shapes are written once here and the colours
/// arrive as [LoreDubColors], which a face of the canvas can answer with as
/// readily as the window can.
///
/// Everything below reads a role. Nothing here may name [LoreDubPalette]:
/// a colour named here cannot be repainted, which is the whole point of
/// handing the roles in.
abstract final class AppTheme {
  /// The window's own, and the same window turned over.
  static final light = build(LoreDubColors.light, Brightness.light);
  static final dark = build(LoreDubColors.dark, Brightness.dark);

  static ThemeData build(LoreDubColors colors, Brightness brightness) {
    final scheme = _scheme(colors, brightness);
    const controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    );
    final fieldBorder = OutlineInputBorder(
      borderSide: BorderSide(color: colors.outline),
      borderRadius: const BorderRadius.all(Radius.circular(8)),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.canvas,
      // What a dropdown opens onto.
      canvasColor: colors.raised,
      fontFamily: LoreDubFonts.body,
      // Nunito Sans carries no arrow, and the pipeline is written with one
      // in more than one place. The monospaced face is bundled and has it,
      // so the glyph is drawn from something we ship rather than from
      // whatever font Windows happens to substitute.
      fontFamilyFallback: const [LoreDubFonts.mono],
      visualDensity: VisualDensity.standard,
      textTheme: _text(colors),
      dividerColor: colors.outline,
      cardTheme: CardThemeData(
        color: colors.panel,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.outline),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: colors.onAccent,
          backgroundColor: colors.accent,
          disabledBackgroundColor: colors.outline,
          disabledForegroundColor: colors.mutedInk,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: controlShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.ink,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: colors.strongOutline),
          shape: controlShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accentStrong,
          minimumSize: const Size(44, 44),
          shape: controlShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.ink,
          minimumSize: const Size(48, 48),
          shape: controlShape,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // Sunk into the face rather than raised out of it: filled with the
        // face's own colour a field is an outline and nothing else.
        fillColor: colors.raised,
        labelStyle: TextStyle(color: colors.mutedInk),
        // A focused field floats its label in the ink rather than in the
        // accent that marks what is chosen: on an orange face the two are
        // the same colour, and the name of the field sat in the orange
        // rather than on it.
        floatingLabelStyle: TextStyle(color: colors.ink),
        helperStyle: TextStyle(color: colors.mutedInk),
        hintStyle: TextStyle(color: colors.mutedInk),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colors.accent, width: 2),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.accent,
        inactiveTrackColor: colors.outline,
        thumbColor: colors.accent,
        overlayColor: colors.accent.withValues(alpha: 0.13),
        showValueIndicator: ShowValueIndicator.onDrag,
        // The number that rises over the thumb while it is dragged. Left to
        // Material it came out of whatever theme stood above, which on an
        // orange face put pale text on a pale bubble.
        valueIndicatorColor: colors.accent,
        valueIndicatorTextStyle: TextStyle(color: colors.onAccent, fontWeight: FontWeight.w700),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? colors.onAccent : colors.ink,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? colors.accent : colors.raised,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: colors.strongOutline)),
        ),
      ),
      // Only the on state is spelled out. Off is Material's own, which
      // reads the scheme above and so is already in this face's colours --
      // and dims itself where the switch is disabled, which a colour named
      // here would not.
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (!states.contains(WidgetState.selected)) return null;
          return states.contains(WidgetState.disabled)
              ? colors.accent.withValues(alpha: 0.45)
              : colors.accent;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (!states.contains(WidgetState.selected)) return null;
          return states.contains(WidgetState.disabled) ? colors.raised : colors.onAccent;
        }),
        trackOutlineColor: WidgetStatePropertyAll(colors.outline),
        overlayColor: WidgetStatePropertyAll(colors.accent.withValues(alpha: 0.12)),
      ),
      // The list a dropdown opens: its own surface, and the entries written
      // in this face's ink rather than in the theme above it.
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: colors.ink),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colors.raised),
          surfaceTintColor: WidgetStatePropertyAll(colors.raised),
          side: WidgetStatePropertyAll(BorderSide(color: colors.outline)),
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(colors.ink),
          overlayColor: WidgetStatePropertyAll(colors.accent.withValues(alpha: 0.12)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accent,
        linearTrackColor: colors.outline,
      ),
      focusColor: colors.accent.withValues(alpha: 0.22),
      // LoreDub's own roles, which every widget of ours reads off the
      // context rather than naming a colour by hand.
      extensions: [colors, LoreDubTextStyles.from(colors)],
    );
  }

  /// What Material asks for, answered in roles.
  ///
  /// The surfaces it raises out of a surface of its own accord — the menu a
  /// dropdown opens, the sheet a dialog stands on — are named rather than
  /// left to Material: derived from the scheme they came out paper-coloured
  /// under writing meant for another face, which on the orange nodes is
  /// barely there.
  static ColorScheme _scheme(LoreDubColors colors, Brightness brightness) => ColorScheme(
    brightness: brightness,
    primary: colors.accent,
    onPrimary: colors.onAccent,
    secondary: colors.deep,
    onSecondary: colors.onDeep,
    surface: colors.panel,
    onSurface: colors.ink,
    error: colors.danger,
    onError: colors.raised,
    outline: colors.outline,
    outlineVariant: colors.outline,
    surfaceContainerLowest: colors.panel,
    surfaceContainerLow: colors.panel,
    surfaceContainer: colors.raised,
    surfaceContainerHigh: colors.raised,
    surfaceContainerHighest: colors.raised,
    surfaceTint: colors.panel,
    onSurfaceVariant: colors.mutedInk,
    // What a chosen chip stands on: the dark, so that the one the player
    // picked is told from the one beside it by more than a tick.
    secondaryContainer: colors.deep,
    onSecondaryContainer: colors.onDeep,
    // What Material turns over for a tooltip or a value bubble.
    inverseSurface: colors.raised,
    onInverseSurface: colors.ink,
  );

  /// The lettering. The three Material leaves out of a theme it is not
  /// given -- `titleSmall`, `bodySmall`, `labelSmall` -- are here, which is
  /// why a note no longer has to be written where it stands.
  static TextTheme _text(LoreDubColors colors) => TextTheme(
    headlineSmall: TextStyle(
      fontFamily: LoreDubFonts.display,
      color: colors.ink,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
    ),
    titleLarge: TextStyle(
      fontFamily: LoreDubFonts.display,
      color: colors.ink,
      fontSize: 19,
      fontWeight: FontWeight.w700,
    ),
    titleMedium: TextStyle(color: colors.ink, fontSize: 16, fontWeight: FontWeight.w600),
    titleSmall: TextStyle(color: colors.ink, fontSize: 14, fontWeight: FontWeight.w600),
    bodyMedium: TextStyle(color: colors.ink, fontSize: 14, height: 1.45),
    bodySmall: TextStyle(color: colors.mutedInk, fontSize: 13),
    labelLarge: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.1),
    labelSmall: TextStyle(color: colors.mutedInk, fontSize: 12),
  );
}
