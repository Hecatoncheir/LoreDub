// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

/// A line of explanation in the node panel, in its own small style.
class InspectorNote extends StatelessWidget {
  const InspectorNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12, height: 1.4),
    ),
  );
}
