// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/ui/graph/node_faces.dart';
import 'package:lore_dub/src/ui/graph/node_panel_theme.dart';
import 'package:lore_dub/src/ui/theme.dart';

void main() {
  test('the window carries the roles every widget of ours reads', () {
    final theme = AppTheme.light;

    expect(theme.extension<LoreDubColors>(), LoreDubColors.light);
    expect(theme.extension<LoreDubTextStyles>()?.moduleLabel.color, LoreDubColors.light.ink);
    // The three Material leaves out, which is why notes used to be written
    // where they stood.
    expect(theme.textTheme.bodySmall?.color, LoreDubColors.light.mutedInk);
    expect(theme.textTheme.labelSmall?.color, LoreDubColors.light.mutedInk);
    expect(theme.textTheme.titleSmall?.fontWeight, FontWeight.w600);
  });

  test('the node panel carries the same roles in that node face', () {
    final colors = buildLoreDubPanelTheme(NodeFaces.light.ends).extension<LoreDubColors>()!;

    expect(colors.ink, NodeFaces.light.ends.ink);
    expect(colors.mutedInk, NodeFaces.light.ends.muted);
    // A face has two greys where the window has three: the body is the
    // ground the panel stands on, and the sunk one is everything the
    // window would raise off it.
    expect(colors.canvas, NodeFaces.light.ends.body);
    expect(colors.panel, NodeFaces.light.ends.sunk);
    expect(colors.raised, NodeFaces.light.ends.sunk);
    expect(colors.strongOutline, NodeFaces.light.ends.rule);
    expect(colors.accent, NodeFaces.light.ends.chosen);
    expect(
      buildLoreDubPanelTheme(NodeFaces.light.ends)
          .extension<LoreDubTextStyles>()
          ?.monoCaption
          .color,
      NodeFaces.light.ends.muted,
      reason: 'a marking in the panel is said in that face, not the window\'s',
    );
  });

  test('a face is built once, not on every frame of a drag behind the panel', () {
    expect(
      identical(
        buildLoreDubPanelTheme(NodeFaces.light.cast),
        buildLoreDubPanelTheme(NodeFaces.light.cast),
      ),
      isTrue,
    );
    expect(
      identical(
        buildLoreDubPanelTheme(NodeFaces.light.cast),
        buildLoreDubPanelTheme(NodeFaces.light.plain),
      ),
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
