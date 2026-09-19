// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

/// A card arriving on the canvas: it comes up rather than appearing whole,
/// so a card drawn from the toolbar is seen arriving and the scheme lays
/// itself out when the screen is opened.
///
/// Its own controller rather than the canvas's: what it answers is being
/// mounted, which is a thing that happens to one card at a time.
class Appearing extends StatefulWidget {
  const Appearing({super.key, required this.child});

  final Widget child;

  @override
  State<Appearing> createState() => _AppearingState();
}

class _AppearingState extends State<Appearing> with SingleTickerProviderStateMixin {
  late final AnimationController _rising = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  )..forward();

  late final Animation<double> _risen = CurvedAnimation(
    parent: _rising,
    curve: Curves.easeOutCubic,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _rising.value = 1;
  }

  @override
  void dispose() {
    _rising.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _risen, child: widget.child);
}
