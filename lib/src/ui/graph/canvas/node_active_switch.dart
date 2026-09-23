// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

/// The switch on a node's card: a glossary node's pack on or off where the
/// node stands, or the character detection listening to the game or not.
///
/// Drawn small, at the foot of the card beside what the node does, so that
/// muting a pack mid-scene is one click on the canvas rather than a walk to
/// its panel. A bare switch says nothing to a screen reader, so it is named
/// -- once: the tooltip, which says the same to the pointer, is kept out of
/// what is read.
class NodeActiveSwitch extends StatelessWidget {
  const NodeActiveSwitch({
    super.key,
    required this.active,
    required this.onChanged,
    required this.label,
  });

  final bool active;
  final ValueChanged<bool> onChanged;

  /// What the switch turns on, which it is named by.
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: SizedBox(
        width: 40,
        height: 24,
        child: FittedBox(
          child: Switch(value: active, onChanged: onChanged),
        ),
      ),
    ),
  );
}
