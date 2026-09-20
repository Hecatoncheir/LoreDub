// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../theme.dart';

/// What the cast shows while it loads, or when there is no card yet: how
/// to add one.
class EmptyCast extends StatelessWidget {
  const EmptyCast({super.key, required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) => Center(
    child: loading
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.groups_rounded, size: 42, color: context.colors.mutedInk),
                const SizedBox(height: 14),
                Text(
                  AppLocalizations.of(context).charactersEmpty,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
  );
}
