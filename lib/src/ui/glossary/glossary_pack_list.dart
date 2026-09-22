// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/glossary.dart';
import '../../domain/glossary_view.dart';
import '../../domain/pack_filter.dart';
import '../common/confirm_dialog.dart';
import 'bloc/glossary_bloc.dart';
import 'glossary_pack_area.dart';

/// The packs the filter shows, each an area entries are dragged into -- or
/// what there is to say when it shows none.
class GlossaryPackList extends StatelessWidget {
  const GlossaryPackList({
    super.key,
    required this.view,
    required this.filter,
    required this.onExport,
  });

  /// The glossary under the filter the lists are under: a search narrows
  /// what a pack shows as well, so a line can be found and dragged in one
  /// motion.
  final GlossaryView view;

  /// Which packs are shown at all, by name.
  final PackFilter filter;
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
    final packs = view.glossary.packs;
    final shown = [
      for (final pack in packs)
        if (filter.shows(pack.name)) pack,
    ];
    if (shown.isEmpty) {
      return Text(
        packs.isEmpty ? l10n.glossaryPacksEmpty : l10n.packsFilterNothing,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final pack in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlossaryPackArea(
              key: ValueKey('glossary-pack-${pack.id}'),
              pack: pack,
              members: view.membersOf(pack),
              // The count is the pack's own, not what the search left: the
              // pack did not change, only what is shown of it.
              held: pack.entryKeys.length,
              searching: view.filter.searching,
              onRename: (name) =>
                  context.read<GlossaryBloc>().add(GlossaryPackRenamed(pack.id, name)),
              onActive: (active) =>
                  context.read<GlossaryBloc>().add(GlossaryPackSwitched(pack.id, active: active)),
              onExport: pack.entryKeys.isEmpty ? null : () => onExport(pack),
              onDelete: () => _confirmDelete(context, pack),
              onDrop: (drag) => context.read<GlossaryBloc>().add(
                GlossaryEntryFiled(drag.entry, into: pack.id, from: drag.fromPackId),
              ),
              onRemoveMember: (entry) =>
                  context.read<GlossaryBloc>().add(GlossaryEntryUnfiled(entry, from: pack.id)),
            ),
          ),
      ],
    );
  }
}
