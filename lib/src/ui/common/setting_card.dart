// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../theme.dart';

/// One group of settings: a card with a title and, below it, the controls.
class SettingCard extends StatelessWidget {
  const SettingCard({super.key, required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          if (subtitle case final value?) ...[
            const SizedBox(height: 5),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.colors.mutedInk),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}
