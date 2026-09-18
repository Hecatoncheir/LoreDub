// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/glossary.dart';
import '../theme.dart';

/// What is done to a pack as a whole: switch it on for the dubbing, write it
/// to a file, throw it away.
class GlossaryPackControls extends StatelessWidget {
  const GlossaryPackControls({
    super.key,
    required this.pack,
    required this.onActive,
    required this.onExport,
    required this.onDelete,
  });

  final GlossaryPack pack;
  final ValueChanged<bool> onActive;

  /// Null while the pack holds nothing worth writing to a file.
  final VoidCallback? onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Tooltip(
          message: l10n.glossaryPackActiveHint,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                key: ValueKey('glossary-pack-active-${pack.id}'),
                value: pack.active,
                onChanged: onActive,
              ),
              Text(
                l10n.glossaryPackActive,
                style: TextStyle(
                  fontSize: 12,
                  color: pack.active ? LoreDubPalette.orange : LoreDubPalette.mutedInk,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: l10n.packsExportHint,
          onPressed: onExport,
          icon: const Icon(Icons.file_upload_outlined, size: 20),
        ),
        IconButton(
          key: ValueKey('glossary-pack-delete-${pack.id}'),
          tooltip: l10n.packsDelete,
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded, size: 20),
        ),
      ],
    );
  }
}
