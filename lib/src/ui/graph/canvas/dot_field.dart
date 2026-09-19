// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math' as math;
import 'dart:ui';

/// One card as the field behind it sees it: where it stands on the screen,
/// how much of it is there — a card arriving or leaving is only partly — and
/// whether the player has it picked out.
class FieldCard {
  const FieldCard({required this.rect, required this.strength, required this.chosen});

  final Rect rect;
  final double strength;
  final bool chosen;
}

/// Where one dot of the field is drawn: pushed off the cards near it, how
/// much of a chosen card's light it carries, and how much of it is left.
typedef FieldDot = ({Offset at, int shade, int left});

/// How the field of dots gives way to the cards on it, in pixels for one
/// frame's zoom. Pure: the painter asks it for every dot it draws.
class DotField {
  DotField(double step)
    : reach = reachDots * step,
      push = pushDots * step,
      glow = glowDots * step,
      dims = dimsDots * step;

  /// How far from a card the field is disturbed, and how far the dot
  /// nearest it is moved. Both in dots rather than in pixels, so the field
  /// parts the same way at any zoom: near enough a dot's width, which reads
  /// as the lattice giving way rather than as a hole in it.
  static const double reachDots = 3.2;
  static const double pushDots = 0.62;

  /// How far the light of a chosen card carries.
  static const double glowDots = 7;

  /// How near a card a dot may come before it starts to go out, in dots.
  /// The card covers the ground it stands on, and a dot that went between
  /// one frame and the next was seen to go: it thins as the card comes over
  /// it instead, and comes back the same way.
  static const double dimsDots = 1.4;

  /// How many shades the light is drawn in, and how many steps there are
  /// between a dot and nothing.
  static const int shades = 10;
  static const int steps = 5;

  final double reach;
  final double push;
  final double glow;
  final double dims;

  /// How far either side of a card the field feels it.
  double spanOf(FieldCard card) => card.chosen ? math.max(reach, glow) : reach;

  /// [at] moved out of the way of [cards], or null where a card stands on it
  /// or has put it out. A dot answers every card near it, so the field parts
  /// rather than snapping from one card's push to the next's.
  FieldDot? place(Offset at, List<FieldCard> cards) {
    final pull = _Pull();
    for (final card in cards) {
      final span = spanOf(card);
      if (at.dy <= card.rect.top - span || at.dy >= card.rect.bottom + span) continue;
      final awayX = at.dx - at.dx.clamp(card.rect.left, card.rect.right);
      final awayY = at.dy - at.dy.clamp(card.rect.top, card.rect.bottom);
      final away = math.sqrt(awayX * awayX + awayY * awayY);
      if (away < 0.01) return null;
      _feel(pull, card, awayX, awayY, away);
    }
    final left = (pull.showing * steps).round();
    if (left <= 0) return null;
    return (
      at: pull.dx == 0 && pull.dy == 0 ? at : Offset(at.dx + pull.dx, at.dy + pull.dy),
      shade: (pull.light * shades).round(),
      left: left,
    );
  }

  /// What one card [away] from the dot does to it.
  void _feel(_Pull pull, FieldCard card, double awayX, double awayY, double away) {
    if (card.chosen && away < glow) {
      // The light of the nearest chosen card, rather than the sum of them:
      // two cards chosen side by side are not twice as chosen.
      final falls = 1 - away / glow;
      pull.light = math.max(pull.light, falls * falls * card.strength);
    }
    if (away < dims) {
      // Measured where the dot started rather than where it is pushed to:
      // what puts it out is the card coming over it.
      pull.showing = math.min(pull.showing, 1 - card.strength * (1 - away / dims));
    }
    if (away >= reach) return;
    // Hardest against the edge and gone by the end of its reach, squared so
    // the field bends rather than breaks.
    final falls = 1 - away / reach;
    final shove = push * falls * falls * card.strength / away;
    pull.dx += awayX * shove;
    pull.dy += awayY * shove;
  }
}

/// What the cards near one dot add up to, gathered card by card.
class _Pull {
  double dx = 0;
  double dy = 0;
  double light = 0;
  double showing = 1;
}
