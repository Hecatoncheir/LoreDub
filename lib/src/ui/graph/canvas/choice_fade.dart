// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/foundation.dart';

/// How far the field of dots has come round to the choice: a card picked
/// out holds the dots off, one let go stops, and neither happens between
/// two frames.
///
/// Pure, and told the time rather than keeping it: the canvas runs one
/// controller for the lot, and the painter asks this what each card is
/// worth at the moment it draws.
@immutable
class ChoiceFade {
  const ChoiceFade({this.chosen = const {}, this.from = const {}});

  /// The cards picked out now, which is where every one of them is going.
  final Set<String> chosen;

  /// Where a card stood when the run began, for the ones on their way. A
  /// card that is already where it is going is not named here.
  final Map<String, double> from;

  /// Whether the field has arrived and the run can be let go of.
  bool get settled => from.isEmpty;

  /// How much of the choice the card [id] carries, [t] of the way through
  /// the run: none, all of it, or on its way between the two.
  double of(String id, double t) {
    final target = chosen.contains(id) ? 1.0 : 0.0;
    final start = from[id];
    if (start == null) return target;
    return start + (target - start) * t;
  }

  /// The fade towards [now], taken up from where every card stands [t] of
  /// the way through the run this one is in. A choice made while the last
  /// is still settling carries on from where it had got to rather than
  /// starting again from nothing.
  ChoiceFade towards(Set<String> now, double t) {
    final moving = <String, double>{};
    for (final id in {...chosen, ...now, ...from.keys}) {
      final at = of(id, t);
      final target = now.contains(id) ? 1.0 : 0.0;
      if ((at - target).abs() > 0.001) moving[id] = at;
    }
    return ChoiceFade(chosen: now, from: moving);
  }
}
