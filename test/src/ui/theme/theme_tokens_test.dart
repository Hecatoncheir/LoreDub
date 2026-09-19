// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/ui/graph/node_paint.dart';
import 'package:lore_dub/src/ui/theme.dart';

void main() {
  test('the window carries the roles every widget of ours reads', () {
    final theme = buildLoreDubTheme();

    expect(theme.extension<LoreDubColors>(), LoreDubColors.light);
    expect(theme.extension<LoreDubTextStyles>()?.moduleLabel.color, LoreDubColors.light.ink);
    // The three Material leaves out, which is why notes used to be written
    // where they stood.
    expect(theme.textTheme.bodySmall?.color, LoreDubColors.light.mutedInk);
    expect(theme.textTheme.labelSmall?.color, LoreDubColors.light.mutedInk);
    expect(theme.textTheme.titleSmall?.fontWeight, FontWeight.w600);
  });

  test('the node panel carries the same roles in that node face', () {
    final colors = buildLoreDubPanelTheme(NodePaint.ends).extension<LoreDubColors>()!;

    expect(colors.ink, NodePaint.ends.ink);
    expect(colors.mutedInk, NodePaint.ends.muted);
    expect(colors.panel, NodePaint.ends.body);
    expect(colors.accent, NodePaint.ends.chosen);
    expect(
      buildLoreDubPanelTheme(NodePaint.ends).extension<LoreDubTextStyles>()?.monoCaption.color,
      NodePaint.ends.muted,
      reason: 'a marking in the panel is said in that face, not the window\'s',
    );
  });

  test('a face is built once, not on every frame of a drag behind the panel', () {
    expect(
      identical(buildLoreDubPanelTheme(NodePaint.cast), buildLoreDubPanelTheme(NodePaint.cast)),
      isTrue,
    );
    expect(
      identical(buildLoreDubPanelTheme(NodePaint.cast), buildLoreDubPanelTheme(NodePaint.plain)),
      isFalse,
      reason: 'and each face keeps its own',
    );
  });

  test('the roles travel between two faces rather than jumping', () {
    final half = LoreDubColors.light.lerp(
      LoreDubColors.light.copyWith(ink: const Color(0xFFFFFFFF)),
      0.5,
    );

    expect(half.ink, isNot(LoreDubColors.light.ink));
    expect(half.canvas, LoreDubColors.light.canvas);
  });
}
