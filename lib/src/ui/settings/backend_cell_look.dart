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

  factory BackendCellLook.of(
    BackendCellState state, {
    required bool hovered,
    required bool tappable,
  }) {
    final ink = _ink(state);
    return BackendCellLook(
      face: _face(state),
      ink: ink,
      edge: _edge(state, hovered: hovered && tappable),
      edgeWidth: state.edged ? 2 : 1,
      icon: _icon(state),
      iconColour: state == BackendCellState.selected || state == BackendCellState.needsRuntime
          ? LoreDubPalette.orange
          : ink,
    );
  }

  static Color _ink(BackendCellState state) => switch (state) {
    BackendCellState.selected => LoreDubPalette.raised,
    BackendCellState.downloading => LoreDubPalette.orange,
    BackendCellState.noHardware ||
    BackendCellState.unsupported => LoreDubPalette.mutedInk.withValues(alpha: 0.7),
    BackendCellState.ready || BackendCellState.needsRuntime => LoreDubPalette.ink,
  };

  static Color _face(BackendCellState state) {
    if (state == BackendCellState.selected) return LoreDubPalette.graphite;
    return state.off ? Colors.transparent : LoreDubPalette.panel;
  }

  static Color _edge(BackendCellState state, {required bool hovered}) {
    if (state.edged) return LoreDubPalette.orange;
    if (hovered) return LoreDubPalette.ink;
    return LoreDubPalette.outline.withValues(alpha: state.off ? 0.5 : 1);
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
