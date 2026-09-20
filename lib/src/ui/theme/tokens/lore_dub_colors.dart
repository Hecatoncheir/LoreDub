// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import 'palette.dart';

/// What a colour is *for*, rather than what it is: the roles every widget of
/// LoreDub paints itself in, carried by the theme so that a second face --
/// the node panel today, a dark interface later -- is another set of the
/// same roles rather than a second set of widgets.
///
/// The raw colours behind these live in [LoreDubPalette], which is on its
/// way out: a widget that names one is a widget the theme cannot repaint,
/// and `tool/ratchet.dart` counts what is left.
@immutable
class LoreDubColors extends ThemeExtension<LoreDubColors> {
  const LoreDubColors({
    required this.canvas,
    required this.panel,
    required this.raised,
    required this.ink,
    required this.mutedInk,
    required this.outline,
    required this.accent,
    required this.accentStrong,
    required this.onAccent,
    required this.deep,
    required this.onDeep,
    required this.onDeepMuted,
    required this.onAccentMuted,
    required this.success,
    required this.warning,
    required this.danger,
    required this.shadow,
  });

  /// The interface as it stands: paper under the panels, orange for what the
  /// player chose, graphite where a surface is dark.
  static const light = LoreDubColors(
    canvas: LoreDubPalette.canvas,
    panel: LoreDubPalette.panel,
    raised: LoreDubPalette.raised,
    ink: LoreDubPalette.ink,
    mutedInk: LoreDubPalette.mutedInk,
    outline: LoreDubPalette.outline,
    accent: LoreDubPalette.orange,
    accentStrong: LoreDubPalette.orangeDark,
    onAccent: LoreDubPalette.ink,
    deep: LoreDubPalette.graphite,
    onDeep: LoreDubPalette.raised,
    onDeepMuted: _onDeepMuted,
    onAccentMuted: _onAccentMuted,
    success: LoreDubPalette.success,
    warning: LoreDubPalette.warning,
    danger: LoreDubPalette.error,
    shadow: _shadow,
  );

  /// What a line of text stands on, farthest back first.
  final Color canvas;
  final Color panel;
  final Color raised;

  /// What is written on [panel] and [raised]: the text itself, and the
  /// quieter half of it -- a note, a unit, a name under a card.
  final Color ink;
  final Color mutedInk;

  /// The hairline around a panel, a tile, a field.
  final Color outline;

  /// What the player chose, and what is written on it. [accentStrong] is the
  /// same accent where it has to hold its own against the paper -- a small
  /// marking, a line of warning text.
  final Color accent;
  final Color accentStrong;
  final Color onAccent;

  /// A dark surface -- a card of the cast, the head of a node, what the
  /// pointer carries -- and what is written on it.
  final Color deep;
  final Color onDeep;
  final Color onDeepMuted;

  /// The quieter half of what is written on the accent, which carries
  /// further than on the dark: the accent is the brighter ground.
  final Color onAccentMuted;

  /// What a state is said in, beside the words that say it.
  final Color success;
  final Color warning;
  final Color danger;

  /// What is cast under a card that is lifted.
  final Color shadow;

  static const _onDeepMuted = Color(0xAAF7F5F0);
  static const _onAccentMuted = Color(0xCCF7F5F0);
  static const _shadow = Color(0x22171717);

  @override
  LoreDubColors copyWith({
    Color? canvas,
    Color? panel,
    Color? raised,
    Color? ink,
    Color? mutedInk,
    Color? outline,
    Color? accent,
    Color? accentStrong,
    Color? onAccent,
    Color? deep,
    Color? onDeep,
    Color? onDeepMuted,
    Color? onAccentMuted,
    Color? success,
    Color? warning,
    Color? danger,
    Color? shadow,
  }) => LoreDubColors(
    canvas: canvas ?? this.canvas,
    panel: panel ?? this.panel,
    raised: raised ?? this.raised,
    ink: ink ?? this.ink,
    mutedInk: mutedInk ?? this.mutedInk,
    outline: outline ?? this.outline,
    accent: accent ?? this.accent,
    accentStrong: accentStrong ?? this.accentStrong,
    onAccent: onAccent ?? this.onAccent,
    deep: deep ?? this.deep,
    onDeep: onDeep ?? this.onDeep,
    onDeepMuted: onDeepMuted ?? this.onDeepMuted,
    onAccentMuted: onAccentMuted ?? this.onAccentMuted,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    shadow: shadow ?? this.shadow,
  );

  @override
  LoreDubColors lerp(LoreDubColors? other, double t) {
    if (other == null) return this;
    return LoreDubColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      mutedInk: Color.lerp(mutedInk, other.mutedInk, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentStrong: Color.lerp(accentStrong, other.accentStrong, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      deep: Color.lerp(deep, other.deep, t)!,
      onDeep: Color.lerp(onDeep, other.onDeep, t)!,
      onDeepMuted: Color.lerp(onDeepMuted, other.onDeepMuted, t)!,
      onAccentMuted: Color.lerp(onAccentMuted, other.onAccentMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}
