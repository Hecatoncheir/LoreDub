// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import 'ease.dart';

/// Grows its child a little under the pointer, so the model about to be
/// clicked stands out without the layout shifting around it.
class HoverGrow extends StatefulWidget {
  const HoverGrow({
    super.key,
    required this.builder,
    this.alignment = Alignment.bottomCenter,
    this.scale = 1.04,
  });

  final Widget Function(BuildContext context, bool hovered) builder;

  /// The point that stays put: a Whisper bar grows up from its axis.
  final Alignment alignment;
  final double scale;

  @override
  State<HoverGrow> createState() => _HoverGrowState();
}

class _HoverGrowState extends State<HoverGrow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? widget.scale : 1,
        alignment: widget.alignment,
        duration: ease(context, 160),
        curve: Curves.easeOutCubic,
        child: widget.builder(context, _hovered),
      ),
    );
  }
}
