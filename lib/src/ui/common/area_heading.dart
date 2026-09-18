// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

/// The head of an area: its number and name on one side, what can be done
/// to it on the other. In a column too narrow to hold both, the buttons
/// drop to a line of their own rather than off the edge.
class AreaHeading extends StatelessWidget {
  const AreaHeading({super.key, required this.label, required this.actions});

  final Widget label;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    runSpacing: 4,
    children: [
      label,
      Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
    ],
  );
}
