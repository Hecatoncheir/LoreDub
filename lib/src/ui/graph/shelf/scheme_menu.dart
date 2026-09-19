// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/saved_pipeline.dart';
import 'name_dialog.dart';

/// What can be done to a kept scheme: write the canvas over it, rename it,
/// hand it on as a file, throw it away.
class SchemeMenu extends StatelessWidget {
  const SchemeMenu({
    super.key,
    required this.scheme,
    required this.onReplace,
    required this.onRename,
    required this.onRemove,
    required this.onExport,
  });

  final SavedPipeline scheme;
  final VoidCallback onReplace;
  final ValueChanged<String> onRename;
  final VoidCallback onRemove;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      tooltip: l10n.pipelineSchemeMenu,
      icon: const Icon(Icons.more_vert_rounded, size: 18),
      style: IconButton.styleFrom(
        minimumSize: const Size(30, 30),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onSelected: (choice) => switch (choice) {
        'replace' => onReplace(),
        'rename' => _rename(context, l10n),
        'export' => onExport(),
        _ => onRemove(),
      },
      itemBuilder: (context) => [
        // First of them: a scheme is worked on, and this is what the menu
        // is opened for once it has been kept.
        PopupMenuItem(value: 'replace', child: Text(l10n.pipelineSchemeReplace)),
        PopupMenuItem(value: 'rename', child: Text(l10n.pipelineSchemeRename)),
        PopupMenuItem(value: 'export', child: Text(l10n.pipelineSchemeExport)),
        PopupMenuItem(value: 'delete', child: Text(l10n.pipelineSchemeDelete)),
      ],
    );
  }

  Future<void> _rename(BuildContext context, AppLocalizations l10n) async {
    final name = await askForName(
      context,
      title: l10n.pipelineSchemeName,
      action: l10n.pipelineSchemeRename,
      initial: scheme.name,
    );
    if (name != null) onRename(name);
  }
}
