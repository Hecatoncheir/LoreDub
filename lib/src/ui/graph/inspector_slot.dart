// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

/// The panel down the right edge of the canvas, coming and going.
///
/// It travels its own whole width, so the edge it comes out from under is
/// the frame of the editing area: the card the scheme is drawn in clips it,
/// and until it is out it is under that frame rather than beside it.
///
/// Which curve carries it is decided here rather than left to the switcher,
/// because [AnimatedSwitcher] hands a panel its curves once, as that panel
/// is made. Another node is another panel, keyed by the node so the switcher
/// sees it as one, and those two take turns rather than crossing: the panel
/// of the node let go of leaves over the half of the run that is its own,
/// and the one clicked comes in over the other half. A panel opening on a
/// canvas with nothing on it has nobody to wait for, and waiting all the
/// same is what made the first click read as a click that missed.
class InspectorSlot extends StatefulWidget {
  const InspectorSlot({super.key, required this.panel});

  /// The panel of the chosen node, or nothing while no node is chosen.
  final Widget? panel;

  @override
  State<InspectorSlot> createState() => _InspectorSlotState();
}

class _InspectorSlotState extends State<InspectorSlot> {
  /// Half of this is what a panel has to itself when it takes turns with
  /// another; a panel with the canvas to itself travels for all of it.
  static const _run = Duration(milliseconds: 360);

  /// The half of the run a panel waits out before it comes in, when there
  /// is one leaving ahead of it.
  static const _behind = Interval(0.5, 1, curve: Curves.easeOutCubic);

  /// A panel's own curve is run backwards as it leaves, so the back half of
  /// the range is the front half of the leaving: it is gone by the time the
  /// panel replacing it starts to move.
  static const _leaving = Interval(0.5, 1, curve: Curves.easeInCubic);

  /// Whether the panel now coming in has one to wait for.
  bool _behindAnother = false;

  @override
  void didUpdateWidget(covariant InspectorSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _behindAnother = oldWidget.panel != null && widget.panel != null;
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: _run,
    switchInCurve: _behindAnother ? _behind : Curves.easeOutCubic,
    switchOutCurve: _leaving,
    transitionBuilder: (child, animation) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(animation),
      // Solid for all but the first third of the way out, while it is
      // still mostly under the frame: the panel slides rather than fades,
      // and the fade is here to take the shadow it casts on the scheme off
      // the canvas with it rather than to be seen. At full strength that
      // shadow stands at the edge of the canvas for as long as the panel is
      // held there, and then goes out all at once.
      child: FadeTransition(
        opacity: CurveTween(curve: const Interval(0, 0.35)).animate(animation),
        child: child,
      ),
    ),
    child: widget.panel,
  );
}
