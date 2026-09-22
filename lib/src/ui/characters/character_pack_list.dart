// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/character.dart';
import '../../domain/pack_filter.dart';
import '../common/confirm_dialog.dart';
import '../common/file_dialogs.dart';
import '../theme.dart';
import 'bloc/cast_bloc.dart';
import 'character_pack_area.dart';

/// The packs the filter shows, each an area cards are dropped into -- or
/// what there is to say when it shows none.
class CharacterPackList extends StatelessWidget {
  const CharacterPackList({super.key, required this.state, required this.filter});

  final CastState state;

  /// Which packs are shown at all, by name.
  final PackFilter filter;

  Future<void> _export(BuildContext context, CharacterPack pack, List<Character> members) async {
    final cast = context.read<CastBloc>();
    final name = pack.name.trim().isEmpty ? 'pack' : pack.name;
    final location = await context.read<FileDialogs>().saveJson('$name.json');
    if (location == null) return;
    cast.add(CastExported(location, members, pack: pack));
  }

  /// The export of [pack], or none for a pack with nobody in it.
  VoidCallback? _exporter(BuildContext context, CharacterPack pack, List<Character> members) {
    if (pack.characterIds.isEmpty) return null;
    return () => _export(context, pack, members);
  }

  Future<void> _confirmDelete(BuildContext context, CharacterPack pack) async {
    final cast = context.read<CastBloc>();
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmRemoval(
      context,
      title: l10n.packsDeleteTitle,
      message: l10n.packsDeleteMessage(pack.name),
      cancelLabel: l10n.charactersDeleteCancel,
      confirmLabel: l10n.charactersDeleteConfirm,
    );
    if (confirmed) cast.add(PackRemoved(pack.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (state.packs.isEmpty) {
      return Row(
        children: [
          Icon(Icons.inventory_2_outlined, size: 20, color: context.colors.mutedInk),
          const SizedBox(width: 12),
          Expanded(child: Text(l10n.packsEmpty)),
        ],
      );
    }
    final shown = [
      for (final pack in state.packs)
        if (filter.shows(pack.name)) pack,
    ];
    if (shown.isEmpty) {
      return Text(l10n.packsFilterNothing, style: Theme.of(context).textTheme.bodySmall);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final pack in shown) ...[
          CharacterPackArea(
            key: ValueKey(pack.id),
            pack: pack,
            members: state.membersOf(pack),
            onRename: (name) => context.read<CastBloc>().add(PackRenamed(pack.id, name)),
            onExport: _exporter(context, pack, state.membersOf(pack)),
            onDelete: () => _confirmDelete(context, pack),
            onDrop: (drag) => context.read<CastBloc>().add(CardPacked(pack.id, drag.character.id)),
            onRemoveMember: (character) =>
                context.read<CastBloc>().add(CardUnpacked(pack.id, character.id)),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
