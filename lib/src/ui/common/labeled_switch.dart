// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

/// A switch with what it turns on written beside it. A null [onChanged]
/// leaves it drawn but locked, the way a running session locks the page.
class LabeledSwitch extends StatelessWidget {
  const LabeledSwitch({
    super.key,
    this.switchKey,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  /// The key the switch itself carries, for whoever has to find it.
  final Key? switchKey;
  final bool value;
  final String label;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Switch(key: switchKey, value: value, onChanged: onChanged),
      const SizedBox(width: 6),
      Flexible(child: Text(label)),
    ],
  );
}
