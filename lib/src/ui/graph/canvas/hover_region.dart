// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

/// The pointer resting on something, for the widget under it to answer with.
/// A card lifts a little under the pointer, which says it can be taken hold
/// of before it is.
class HoverRegion extends StatefulWidget {
  const HoverRegion({super.key, required this.cursor, required this.builder});

  final MouseCursor cursor;
  final Widget Function(BuildContext context, bool hovered) builder;

  @override
  State<HoverRegion> createState() => _HoveringState();
}

class _HoveringState extends State<HoverRegion> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: widget.cursor,
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: widget.builder(context, _hovered),
  );
}
