// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../theme.dart';

/// The card's rarer two, in the shape the schemes shelf keeps its own in.
class CharacterCardMenu extends StatelessWidget {
  const CharacterCardMenu({super.key, required this.onExport, required this.onDelete});

  final VoidCallback? onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      // Named, or a reader hears an unlabelled button beside two that say
      // what they do.
      tooltip: l10n.charactersCardMenu,
      icon: const Icon(Icons.more_horiz_rounded, size: 19),
      style: IconButton.styleFrom(
        foregroundColor: LoreDubPalette.ink,
        hoverColor: LoreDubPalette.orange.withValues(alpha: 0.18),
        minimumSize: const Size.square(LoreDubTargets.dense),
        fixedSize: const Size.square(LoreDubTargets.dense),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onSelected: (choice) => switch (choice) {
        'export' => onExport?.call(),
        _ => onDelete(),
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'export',
          enabled: onExport != null,
          child: Text(l10n.charactersExportHint),
        ),
        PopupMenuItem(value: 'delete', child: Text(l10n.charactersDelete)),
      ],
    );
  }
}
