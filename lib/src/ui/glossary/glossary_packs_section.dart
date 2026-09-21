// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/glossary.dart';
import '../../domain/glossary_view.dart';
import '../theme.dart';
import '../dashboard/cubits/glossary_bloc.dart';
import '../common/confirm_dialog.dart';
import 'glossary_heading.dart';
import 'glossary_pack_area.dart';

/// The shelf of packs, under the three lists it groups.
///
/// A pack is a way of reading the glossary rather than a place entries are
/// moved to: every entry stays in its list whether or not a pack names it.
/// Switching one on narrows what the dubbing reads to the packs that are on
/// -- see [Glossary.inUse].
class GlossaryPacksSection extends StatelessWidget {
  const GlossaryPacksSection({
    super.key,
    required this.view,
    required this.onImport,
    required this.onExport,
  });

  /// The glossary under the filter the lists are under: a search narrows
  /// what a pack shows as well, so a line can be found and dragged in one
  /// motion.
  final GlossaryView view;
  final VoidCallback onImport;
  final ValueChanged<GlossaryPack> onExport;

  /// A pack is only a way of reading the glossary, so throwing one away
  /// leaves every entry in its list -- but the grouping took the player
  /// dragging to make, and is asked about like a pack of cards is.
  Future<void> _confirmDelete(BuildContext context, GlossaryPack pack) async {
    final glossary = context.read<GlossaryBloc>();
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmRemoval(
      context,
      title: l10n.packsDeleteTitle,
      message: l10n.glossaryPackDeleteMessage(pack.name),
      cancelLabel: l10n.charactersDeleteCancel,
      confirmLabel: l10n.charactersDeleteConfirm,
    );
    if (confirmed) glossary.add(GlossaryPackRemoved(pack.id));
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
                  onPressed: onImport,
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  label: Text(l10n.glossaryPackImport),
                  style: TextButton.styleFrom(foregroundColor: context.colors.mutedInk),
                ),
                TextButton.icon(
                  key: const ValueKey('glossary-pack-add'),
                  onPressed: () =>
                      context.read<GlossaryBloc>().add(GlossaryPackAdded(l10n.packsNewName)),
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
            if (view.glossary.packs.isEmpty)
              Text(
                l10n.glossaryPacksEmpty,
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              for (final pack in view.glossary.packs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlossaryPackArea(
                    key: ValueKey('glossary-pack-${pack.id}'),
                    pack: pack,
                    members: view.membersOf(pack),
                    // The count is the pack's own, not what the search left:
                    // the pack did not change, only what is shown of it.
                    held: pack.entryKeys.length,
                    searching: view.filter.searching,
                    onRename: (name) =>
                        context.read<GlossaryBloc>().add(GlossaryPackRenamed(pack.id, name)),
                    onActive: (active) => context.read<GlossaryBloc>().add(
                      GlossaryPackSwitched(pack.id, active: active),
                    ),
                    onExport: pack.entryKeys.isEmpty ? null : () => onExport(pack),
                    onDelete: () => _confirmDelete(context, pack),
                    onDrop: (drag) => context.read<GlossaryBloc>().add(
                      GlossaryEntryFiled(drag.entry, into: pack.id, from: drag.fromPackId),
                    ),
                    onRemoveMember: (entry) => context.read<GlossaryBloc>().add(
                      GlossaryEntryUnfiled(entry, from: pack.id),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
