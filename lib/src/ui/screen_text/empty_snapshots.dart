// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../theme.dart';

/// What the snapshot history shows before anything has been picked out:
/// how to pick it.
class EmptySnapshots extends StatelessWidget {
  const EmptySnapshots({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: constraints.maxHeight > 24 ? constraints.maxHeight - 24 : 0,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.highlight_alt_rounded, size: 42, color: LoreDubPalette.mutedInk),
              const SizedBox(height: 14),
              Text(AppLocalizations.of(context).snapshotEmpty, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ),
  );
}
