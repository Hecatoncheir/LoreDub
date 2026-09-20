// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/ui/common/tile_edge.dart';
import 'package:lore_dub/src/ui/theme.dart';

void main() {
  const colors = LoreDubColors.light;

  test('a marked tile wears the accent, twice as thick', () {
    final edge = TileEdge.of(colors, marked: true, hovered: false);
    expect(edge.color, colors.accent);
    expect(edge.width, 2);
  });

  test('the mark beats the pointer', () {
    expect(
      TileEdge.of(colors, marked: true, hovered: true),
      TileEdge.of(colors, marked: true, hovered: false),
    );
  });

  test('the pointer darkens a tile that is not marked', () {
    expect(TileEdge.of(colors, marked: false, hovered: true).color, colors.ink);
  });

  test('a tile nothing will happen to keeps half an outline', () {
    final quiet = TileEdge.of(colors, marked: false, hovered: false, quiet: true);
    final plain = TileEdge.of(colors, marked: false, hovered: false);
    expect(plain.color, colors.outline);
    expect(quiet.color.a, closeTo(plain.color.a / 2, 0.001));
    expect(quiet.width, plain.width);
  });

  test('the corner is the screen\'s, the edge its own', () {
    final shape = TileEdge.of(colors, marked: true, hovered: false).shaped(10);
    expect(shape.borderRadius, const BorderRadius.all(Radius.circular(10)));
    expect(shape.side.color, colors.accent);
    expect(shape.side.width, 2);
  });
}
