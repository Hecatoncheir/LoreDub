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
    required this.strongOutline,
    required this.accent,
    required this.accentStrong,
    required this.onAccent,
    required this.deep,
    required this.onDeep,
    required this.onDeepMuted,
    required this.onAccentLight,
    required this.onAccentMuted,
    required this.accentDeep,
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
    strongOutline: LoreDubPalette.graphite,
    accent: LoreDubPalette.orange,
    accentStrong: LoreDubPalette.orangeDark,
    onAccent: LoreDubPalette.ink,
    deep: LoreDubPalette.graphite,
    onDeep: LoreDubPalette.raised,
    onDeepMuted: _onDeepMuted,
    onAccentLight: LoreDubPalette.raised,
    onAccentMuted: _onAccentMuted,
    accentDeep: LoreDubPalette.orangeDark,
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

  /// The same line where it has to hold its own against the ink beside it:
  /// the edge of a control the player can press. On a face of the canvas
  /// there is no second line, and the rule does this work as well.
  final Color strongOutline;

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

  /// The accent takes writing both ways, and it is the one colour that
  /// does not turn over with the theme, so neither do these: [onAccent] is
  /// the dark a control's label is set in, and [onAccentLight] the light a
  /// node's title is, which was measured to read where the dark sat in the
  /// colour rather than on it. [onAccentMuted] is that light's quieter
  /// half, which carries further than on the dark: the accent is the
  /// brighter ground.
  final Color onAccentLight;
  final Color onAccentMuted;

  /// The accent a shade deeper, which does not turn over either: what a
  /// field is sunk into on a surface of the accent, where [onAccentLight]
  /// is written. [accentStrong] turns lighter against the ink, and a field
  /// filled with it held those light letters at no contrast at all.
  final Color accentDeep;

  /// What a state is said in, beside the words that say it.
  final Color success;
  final Color warning;
  final Color danger;

  /// What is cast under a card that is lifted.
  final Color shadow;

  /// The interface turned over. Every role answers with what it answers
  /// with on a card of the cast, which is the dark this application
  /// already has: the ink is the ground, the graphite is what stands on
  /// it, and the cream a dark node is written in is the text.
  ///
  /// Three roles do not simply swap. [deep] means a dark surface against
  /// the ground, and on the ink there is no darker one, so here it is the
  /// pale one -- a chosen chip, a card of the cast, the head of a node --
  /// with the ink written on it. [accentStrong] is the accent where it has
  /// to hold its own, which against paper means darker and against the ink
  /// means lighter. And the three states are lifted for the same reason:
  /// at the values the paper needs they are unreadable on the ground.
  static const dark = LoreDubColors(
    canvas: LoreDubPalette.ink,
    panel: LoreDubPalette.graphite,
    raised: LoreDubPalette.raisedDark,
    ink: LoreDubPalette.raised,
    mutedInk: LoreDubPalette.mutedInkDark,
    outline: LoreDubPalette.outlineDark,
    strongOutline: LoreDubPalette.outline,
    accent: LoreDubPalette.orange,
    accentStrong: LoreDubPalette.orangeLight,
    onAccent: LoreDubPalette.ink,
    deep: LoreDubPalette.panel,
    onDeep: LoreDubPalette.ink,
    onDeepMuted: _onPaleMuted,
    onAccentLight: LoreDubPalette.raised,
    onAccentMuted: _onAccentMuted,
    accentDeep: LoreDubPalette.orangeDark,
    success: LoreDubPalette.successLight,
    warning: LoreDubPalette.warningLight,
    danger: LoreDubPalette.errorLight,
    shadow: _shadowDark,
  );

  static const _onDeepMuted = Color(0xAAF7F5F0);
  static const _onPaleMuted = Color(0xAA171717);
  static const _onAccentMuted = Color(0xCCF7F5F0);
  static const _shadow = Color(0x22171717);

  /// Deeper, because it falls on the ink rather than on paper.
  static const _shadowDark = Color(0x55000000);

  @override
  LoreDubColors copyWith({
    Color? canvas,
    Color? panel,
    Color? raised,
    Color? ink,
    Color? mutedInk,
    Color? outline,
    Color? strongOutline,
    Color? accent,
    Color? accentStrong,
    Color? onAccent,
    Color? deep,
    Color? onDeep,
    Color? onDeepMuted,
    Color? onAccentLight,
    Color? onAccentMuted,
    Color? accentDeep,
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
    strongOutline: strongOutline ?? this.strongOutline,
    accent: accent ?? this.accent,
    accentStrong: accentStrong ?? this.accentStrong,
    onAccent: onAccent ?? this.onAccent,
    deep: deep ?? this.deep,
    onDeep: onDeep ?? this.onDeep,
    onDeepMuted: onDeepMuted ?? this.onDeepMuted,
    onAccentLight: onAccentLight ?? this.onAccentLight,
    onAccentMuted: onAccentMuted ?? this.onAccentMuted,
    accentDeep: accentDeep ?? this.accentDeep,
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
      strongOutline: Color.lerp(strongOutline, other.strongOutline, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentStrong: Color.lerp(accentStrong, other.accentStrong, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      deep: Color.lerp(deep, other.deep, t)!,
      onDeep: Color.lerp(onDeep, other.onDeep, t)!,
      onDeepMuted: Color.lerp(onDeepMuted, other.onDeepMuted, t)!,
      onAccentLight: Color.lerp(onAccentLight, other.onAccentLight, t)!,
      onAccentMuted: Color.lerp(onAccentMuted, other.onAccentMuted, t)!,
      accentDeep: Color.lerp(accentDeep, other.accentDeep, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}
