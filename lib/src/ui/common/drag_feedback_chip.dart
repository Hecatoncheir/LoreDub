// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../theme.dart';

/// What travels under the pointer while an entry is dragged.
class DragFeedbackChip extends StatelessWidget {
  const DragFeedbackChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.deep,
    borderRadius: const BorderRadius.all(Radius.circular(18)),
    elevation: 6,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.raised),
        ),
      ),
    ),
  );
}
