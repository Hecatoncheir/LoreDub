// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/glossary.dart';
import '../../domain/glossary_view.dart';
import '../../domain/pack_filter.dart';
import '../common/pack_filter_field.dart';
import '../theme.dart';
import 'bloc/glossary_bloc.dart';
import 'glossary_heading.dart';
import 'glossary_pack_list.dart';

/// The shelf of packs, under the three lists it groups.
///
/// A pack is a way of reading the glossary rather than a place entries are
/// moved to: every entry stays in its list whether or not a pack names it.
/// Switching one on narrows what the dubbing reads to the packs that are on
/// -- see [Glossary.inUse].
class GlossaryPacksSection extends StatefulWidget {
  const GlossaryPacksSection({
    super.key,
    required this.view,
    required this.onImport,
    required this.onExport,
  });

  /// The glossary under the filter the lists are under.
  final GlossaryView view;
  final VoidCallback onImport;
  final ValueChanged<GlossaryPack> onExport;

  @override
  State<GlossaryPacksSection> createState() => _GlossaryPacksSectionState();
}

class _GlossaryPacksSectionState extends State<GlossaryPacksSection> {
  /// What the shelf is narrowed to by name, kept here rather than in the
  /// field: a pack made or loaded is one the player means to see, and the
  /// field is emptied for it.
  final _named = TextEditingController();

  @override
  void dispose() {
    _named.dispose();
    super.dispose();
  }

  void _import() {
    _named.clear();
    widget.onImport();
  }

  void _add(String name) {
    _named.clear();
    context.read<GlossaryBloc>().add(GlossaryPackAdded(name));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // A `Card`, like the three lists it stands under: drawn by hand it had
    // a corner of its own, sixteen against the twelve `docs/UI_DESIGN.md`
    // promises and the theme gives.
    return Card(
      key: const ValueKey('glossaryPacks'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlossaryHeading(number: '04', label: l10n.glossaryPacks),
            const SizedBox(height: 4),
            // Wrapped rather than in a row: beside the lists this card is a
            // column narrower than the two buttons standing side by side.
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: [
                TextButton.icon(
                  key: const ValueKey('glossary-pack-import'),
                  onPressed: _import,
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  label: Text(l10n.glossaryPackImport),
                  style: TextButton.styleFrom(foregroundColor: context.colors.mutedInk),
                ),
                TextButton.icon(
                  key: const ValueKey('glossary-pack-add'),
                  onPressed: () => _add(l10n.packsNewName),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l10n.packsAdd),
                  style: TextButton.styleFrom(foregroundColor: context.colors.mutedInk),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.glossaryPacksNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            if (widget.view.glossary.packs.isNotEmpty) ...[
              PackFilterField(key: const ValueKey('glossary-pack-filter'), controller: _named),
              const SizedBox(height: 12),
            ],
            ListenableBuilder(
              listenable: _named,
              builder: (context, _) => GlossaryPackList(
                view: widget.view,
                filter: PackFilter(_named.text),
                onExport: widget.onExport,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
