// Copyright (c) 2026 GameLingo contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

ThemeData buildGameLingoTheme() {
  const scheme = ColorScheme.dark(
    primary: Color(0xFF38BDF8),
    onPrimary: Color(0xFF07131B),
    secondary: Color(0xFF22C55E),
    onSecondary: Color(0xFF041109),
    surface: Color(0xFF111827),
    onSurface: Color(0xFFF8FAFC),
    error: Color(0xFFF87171),
    onError: Color(0xFF220707),
  );
  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF0B1120),
    fontFamily: 'Segoe UI',
    visualDensity: VisualDensity.standard,
    cardTheme: const CardThemeData(
      color: Color(0xFF111827),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Color(0xFF253047)),
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF0F172A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
    ),
    sliderTheme: const SliderThemeData(showValueIndicator: ShowValueIndicator.onDrag),
  );
}
