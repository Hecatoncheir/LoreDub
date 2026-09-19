// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../../../domain/pipeline_graph.dart';
import '../../theme.dart';
import 'choice_fade.dart';
import 'dot_field.dart';
import 'node_metrics.dart';

/// The field the scheme sits on: dots that move and grow with the canvas, so
/// panning is visible even where there is no node.
class DotFieldPainter extends CustomPainter {
  DotFieldPainter({
    required this.view,
    required this.nodes,
    required this.grown,
    required this.picked,
    this.fade = const ChoiceFade(),
    this.arriving = const {},
    this.leaving = const {},
  }) : super(repaint: Listenable.merge([grown, picked]));

  final GraphView view;

  /// The cards standing on the field, the ones on their way off it among
  /// them. Where they stand is read off these; which of them the field
  /// answers to is [fade].
  final List<PipelineNode> nodes;

  /// The cards the player has picked out, and the only ones the field
  /// answers to. It parts around them and lights towards them: the nearer a
  /// dot is to one, the more of the orange it carries, so a card that is
  /// chosen is found without hunting for its border. The rest stand on the
  /// field without disturbing it. A card picked out takes the field with it
  /// over [picked] rather than between two frames.
  final ChoiceFade fade;
  final Animation<double> picked;

  /// A chosen card arriving parts the field as it comes, and one leaving
  /// lets it close again: [grown] is how far along both of those are.
  final Set<String> arriving;
  final Set<String> leaving;
  final Animation<double> grown;

  static const double spacing = 18;

  /// How far towards the orange the dot against a chosen card's edge is
  /// taken, and how much bigger it is drawn there. Not the whole way to the
  /// orange: a field of orange would say more than the card being chosen is
  /// worth. The size is what the light is read by at a glance — colour alone,
  /// on dots this small, is barely there.
  static const double lit = 0.85;
  static const double swells = 1.3;

  static const _shades = DotField.shades;
  static const _steps = DotField.steps;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = LoreDubPalette.canvas);
    final step = spacing * view.zoom;
    if (step < 6) return;
    _drawShades(canvas, _sorted(size, step), radius: math.max(0.8, 1.1 * view.zoom));
  }

  /// Every dot of the window, sorted by shade of light and step of fading.
  ///
  /// Drawn a shade at a time rather than a dot at a time: a window this size
  /// holds thousands of them, and they are drawn again on every frame of a
  /// pan. One list per shade and step; most stay empty.
  List<List<Offset>> _sorted(Size size, double step) {
    final field = DotField(step);
    final held = _cards();
    final byShade = List.generate((_shades + 1) * (_steps + 1), (_) => <Offset>[], growable: false);
    // The cards the column being drawn runs through. Kept between columns
    // rather than made again: most columns run through none, and a dot asked
    // against every card on the canvas is thousands of them times the whole
    // cast on every frame of a drag.
    final near = <FieldCard>[];
    for (var x = view.x % step - step; x < size.width + step; x += step) {
      near
        ..clear()
        ..addAll(held.where((card) => _crosses(card, x, field)));
      for (var y = view.y % step - step; y < size.height + step; y += step) {
        if (near.isEmpty) {
          byShade[_steps].add(Offset(x, y));
          continue;
        }
        // A dot the card stands on is not drawn at all: the card holds the
        // ground it covers, and a faded one would show the field through it.
        if (field.place(Offset(x, y), near) case final dot?) {
          byShade[dot.shade * (_steps + 1) + dot.left].add(dot.at);
        }
      }
    }
    return byShade;
  }

  static bool _crosses(FieldCard card, double x, DotField field) {
    final span = field.spanOf(card);
    return x > card.rect.left - span && x < card.rect.right + span;
  }

  void _drawShades(Canvas canvas, List<List<Offset>> byShade, {required double radius}) {
    final plain = LoreDubPalette.outline.withValues(alpha: 0.55);
    for (var shade = 0; shade <= _shades; shade++) {
      final share = shade / _shades;
      final colour = Color.lerp(plain, LoreDubPalette.orange, share * lit)!;
      for (var left = 1; left <= _steps; left++) {
        final dots = byShade[shade * (_steps + 1) + left];
        if (dots.isEmpty) continue;
        final showing = left / _steps;
        canvas.drawPoints(
          PointMode.points,
          dots,
          Paint()
            ..color = colour.withValues(alpha: colour.a * showing)
            // A dot on its way out draws in as it goes, and one near a chosen
            // card swells: the nearer it stands the bigger it is drawn, which
            // is what the light is read by. Round caps make each point the
            // dot it used to be drawn as.
            ..strokeWidth = radius * 2 * (1 + swells * share) * (0.55 + 0.45 * showing)
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  /// How hard [node] holds the field off: less and less as it leaves, more
  /// and more as it arrives.
  double _strengthOf(PipelineNode node) {
    if (arriving.contains(node.id)) return grown.value;
    if (leaving.contains(node.id)) return 1 - grown.value;
    return 1;
  }

  /// Where the chosen cards stand on the screen, with how hard each of them
  /// holds the field off. Worked out once for the frame.
  ///
  /// Only the chosen ones: a scheme of two dozen cards parting the field
  /// under every one of them is a field that is nowhere at rest, and the
  /// parting says nothing, every card doing it. Around the card the player
  /// picked out it says which one that is, together with the light.
  List<FieldCard> _cards() => [
    for (final node in nodes) ?_fieldOf(node),
  ];

  /// [node] as the field sees it, or null while it is nothing to the field:
  /// not chosen, or not yet drawn.
  FieldCard? _fieldOf(PipelineNode node) {
    final strength = _strengthOf(node) * fade.of(node.id, picked.value);
    if (strength <= 0.01) return null;
    final size = NodeMetrics.sizeOf(node.kind);
    return FieldCard(
      rect: Rect.fromLTWH(
        view.x + node.position.x * view.zoom,
        view.y + node.position.y * view.zoom,
        size.width * view.zoom,
        size.height * view.zoom,
      ),
      strength: strength.clamp(0.0, 1.0),
      // Every card the field is told about is one that was chosen.
      chosen: true,
    );
  }

  @override
  bool shouldRepaint(DotFieldPainter old) {
    if (old.view.x != view.x || old.view.y != view.y || old.view.zoom != view.zoom) return true;
    // The canvas holds one fade and makes another only when the choice
    // changes, so the same object is the same choice.
    if (!identical(old.fade, fade)) return true;
    if (old.nodes.length != nodes.length) return true;
    for (var index = 0; index < nodes.length; index++) {
      if (old.nodes[index] != nodes[index]) return true;
    }
    return false;
  }
}
