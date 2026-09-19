// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../common/ease.dart';
import '../theme.dart';
import 'model_action.dart';
import 'model_action_button.dart';
import 'model_progress_dial.dart';
import 'model_tile_heading.dart';
import 'model_tile_part.dart';

/// What a model tile holds, over the dark fill that rises behind it while
/// the model downloads: the heading, the dial of a download, the buttons.
class ModelTileBody extends StatelessWidget {
  const ModelTileBody({
    super.key,
    required this.title,
    required this.parts,
    required this.progress,
    required this.paused,
    required this.installed,
    required this.inUse,
    required this.ink,
    required this.tooltip,
    required this.actions,
  });

  final String title;
  final List<ModelTilePart> parts;
  final double? progress;
  final bool paused;
  final bool installed;
  final bool inUse;
  final Color ink;
  final String tooltip;
  final List<ModelAction> actions;

  static const _actionBand = 44.0;

  /// Whether the buttons stand on the dark: the tile is in use, or the fill
  /// has risen past them.
  bool _darkFoot(double height) {
    final value = progress;
    return inUse || (value != null && value * height >= _actionBand);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Stack(
      fit: StackFit.expand,
      children: [
        if (progress case final value?)
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedFractionallySizedBox(
              duration: ease(context, 300),
              heightFactor: value.clamp(0.0, 1.0),
              widthFactor: 1,
              child: const ColoredBox(color: LoreDubPalette.graphite),
            ),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Tooltip(
              message: tooltip,
              waitDuration: const Duration(milliseconds: 400),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 0),
                child: ModelTileHeading(
                  title: title,
                  parts: parts,
                  downloading: progress != null,
                  installed: installed,
                  inUse: inUse,
                  ink: ink,
                ),
              ),
            ),
            Expanded(
              child: switch (progress) {
                final value? => LayoutBuilder(
                  builder: (context, room) => Center(
                    child: ModelProgressDial(
                      progress: value,
                      paused: paused,
                      size: math.max(
                        28,
                        math.min(76, math.min(room.maxHeight - 6, room.maxWidth * 0.6)),
                      ),
                    ),
                  ),
                ),
                null => const SizedBox.shrink(),
              },
            ),
            SizedBox(
              height: _actionBand,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final action in actions)
                    ModelActionButton(action: action, onDark: _darkFoot(constraints.maxHeight)),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
