// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../theme.dart';

/// What one cell of the stage-by-device table says about its pair.
enum BackendCellState {
  /// The stage runs here.
  selected,

  /// It could, at a click.
  ready,

  /// The card is there but the package for it is not: a click fetches it.
  needsRuntime,

  /// That package is on its way.
  downloading,

  /// No card or driver for this backend on this machine.
  noHardware,

  /// The stage has no build for this backend at all.
  unsupported;

  /// Ruled out by the machine or the stage: drawn faded.
  bool get off => this == noHardware || this == unsupported;

  /// Worn with the orange edge: where the stage runs, or what is arriving.
  bool get edged => this == selected || this == downloading;
}

/// The colours and the mark of a backend cell, decided once from its state.
class BackendCellLook {
  const BackendCellLook({
    required this.face,
    required this.ink,
    required this.edge,
    required this.edgeWidth,
    required this.icon,
    required this.iconColour,
  });

  /// [colors] are the roles the cell is drawn in, handed over rather than
  /// read off a context: the look is decided from the state alone.
  factory BackendCellLook.of(
    BackendCellState state, {
    required LoreDubColors colors,
    required bool hovered,
    required bool tappable,
  }) {
    final ink = _ink(state, colors);
    return BackendCellLook(
      face: _face(state, colors),
      ink: ink,
      edge: _edge(state, colors, hovered: hovered && tappable),
      edgeWidth: state.edged ? 2 : 1,
      icon: _icon(state),
      iconColour: state == BackendCellState.selected || state == BackendCellState.needsRuntime
          ? colors.accent
          : ink,
    );
  }

  static Color _ink(BackendCellState state, LoreDubColors colors) => switch (state) {
    BackendCellState.selected => colors.raised,
    BackendCellState.downloading => colors.accent,
    BackendCellState.noHardware ||
    BackendCellState.unsupported => colors.mutedInk.withValues(alpha: 0.7),
    BackendCellState.ready || BackendCellState.needsRuntime => colors.ink,
  };

  static Color _face(BackendCellState state, LoreDubColors colors) {
    if (state == BackendCellState.selected) return colors.deep;
    return state.off ? Colors.transparent : colors.panel;
  }

  static Color _edge(BackendCellState state, LoreDubColors colors, {required bool hovered}) {
    if (state.edged) return colors.accent;
    if (hovered) return colors.ink;
    return colors.outline.withValues(alpha: state.off ? 0.5 : 1);
  }

  static IconData? _icon(BackendCellState state) => switch (state) {
    BackendCellState.selected => Icons.check_rounded,
    BackendCellState.needsRuntime => Icons.cloud_download_outlined,
    BackendCellState.noHardware => Icons.block_rounded,
    BackendCellState.unsupported => Icons.remove_rounded,
    BackendCellState.ready || BackendCellState.downloading => null,
  };

  final Color face;
  final Color ink;
  final Color edge;
  final double edgeWidth;
  final IconData? icon;
  final Color iconColour;
}
