// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

/// A row of exclusive choices, kept narrow enough for the panel.
class InspectorChoices<T> extends StatelessWidget {
  const InspectorChoices({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });

  final T value;
  final Map<T, String> options;
  final void Function(T value) onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final entry in options.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: entry.key == value,
            onSelected: enabled ? (_) => onChanged(entry.key) : null,
            selectedColor: scheme.primary,
            backgroundColor: Theme.of(context).inputDecorationTheme.fillColor,
            side: BorderSide(color: scheme.outline),
            labelStyle: TextStyle(
              color: entry.key == value ? scheme.onPrimary : scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            showCheckmark: false,
          ),
      ],
    );
  }
}
