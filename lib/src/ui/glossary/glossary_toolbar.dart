// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../theme.dart';

/// The search over the glossary and the file it travels in. Over all the
/// lists rather than beside any one: one file holds them together, and a
/// glossary of a game is worth passing on whole.
class GlossaryToolbar extends StatefulWidget {
  const GlossaryToolbar({
    super.key,
    required this.searching,
    required this.canExport,
    required this.onSearch,
    required this.onImport,
    required this.onExport,
  });

  /// Whether a search is on, which is when the field offers to clear it.
  final bool searching;
  final bool canExport;

  /// What is looked for, trimmed and lower-cased.
  final ValueChanged<String> onSearch;
  final VoidCallback onImport;
  final VoidCallback onExport;

  @override
  State<GlossaryToolbar> createState() => _GlossaryToolbarState();
}

class _GlossaryToolbarState extends State<GlossaryToolbar> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clear() {
    _search.clear();
    widget.onSearch('');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('glossary-search'),
              controller: _search,
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.glossarySearch,
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: widget.searching
                    ? IconButton(
                        key: const ValueKey('glossary-search-clear'),
                        tooltip: l10n.glossarySearchClear,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: _clear,
                      )
                    : null,
              ),
              onChanged: (value) => widget.onSearch(value.trim().toLowerCase()),
            ),
          ),
          const SizedBox(width: 12),
          TextButton.icon(
            key: const ValueKey('glossary-import'),
            onPressed: widget.onImport,
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: Text(l10n.glossaryImport),
            style: TextButton.styleFrom(foregroundColor: LoreDubPalette.mutedInk),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            key: const ValueKey('glossary-export'),
            onPressed: widget.canExport ? widget.onExport : null,
            icon: const Icon(Icons.file_upload_outlined, size: 18),
            label: Text(l10n.glossaryExport),
            style: TextButton.styleFrom(foregroundColor: LoreDubPalette.mutedInk),
          ),
        ],
      ),
    );
  }
}
