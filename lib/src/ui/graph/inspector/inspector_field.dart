// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

/// A labelled control, the way the settings screen sets one out.
class InspectorField extends StatelessWidget {
  const InspectorField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          // The colour comes from the panel's own theme, which carries the
          // face of the node it opened on.
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        child,
      ],
    ),
  );
}
