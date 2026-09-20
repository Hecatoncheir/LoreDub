// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../models/download_fill.dart';
import '../common/hover_grow.dart';
import '../theme.dart';
import 'backend_cell_label.dart';
import 'backend_cell_look.dart';

/// One stage on one device, drawn in the models' vocabulary: dark with an
/// orange edge where the stage runs, light where it could, a download cloud
/// where a package is missing, a fill while it arrives, and faded where the
/// machine or the stage rules it out — with the reason in the tooltip.
class BackendCell extends StatelessWidget {
  const BackendCell({
    super.key,
    required this.label,
    required this.state,
    required this.tooltip,
    this.detail,
    this.progress,
    this.onTap,
  });

  final String label;
  final BackendCellState state;
  final String tooltip;

  /// A size to fetch, or how far the fetch got.
  final String? detail;
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    waitDuration: const Duration(milliseconds: 400),
    child: HoverGrow(
      alignment: Alignment.center,
      scale: onTap == null ? 1 : 1.04,
      builder: (context, hovered) {
        final look = BackendCellLook.of(
          state,
          colors: context.colors,
          hovered: hovered,
          tappable: onTap != null,
        );
        return Semantics(
          button: onTap != null,
          selected: state == BackendCellState.selected,
          label: label,
          child: Material(
            color: look.face,
            clipBehavior: Clip.antiAlias,
            shape: look.edge.shaped(10),
            child: InkWell(
              onTap: onTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (progress case final value?) DownloadFill(progress: value),
                  BackendCellLabel(label: label, look: look, detail: detail),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
