// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../common/file_dialogs.dart';
import '../../domain/character.dart';
import '../../../l10n/app_localizations.dart';
import '../theme.dart';
import '../dashboard/dashboard_context.dart';
import '../common/module_label.dart';
import '../common/area_heading.dart';
import '../common/confirm_dialog.dart';
import 'character_pack_area.dart';
import '../dashboard/cubits/cast_bloc.dart';

/// The packs: named areas cards are dropped into, handed on and thrown away
/// as a group. Throwing one away leaves the cards in the cast — the player
/// recorded them, and only the grouping was ever the pack's.
class CharacterPacks extends StatelessWidget {
  const CharacterPacks({super.key});

  Future<void> _import(BuildContext context) async {
    final cast = context.read<CastBloc>();
    final chosen = await context.read<FileDialogs>().openJson();
    if (chosen.isEmpty) return;
    cast.add(CastImported(chosen));
  }

  /// What an import read, said once it has been read.
  static void _sayImported(BuildContext context, CastState state) {
    final added = state.lastImport;
    if (added == null) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added.packs == 0
              ? l10n.charactersImported(added.characters)
              : l10n.packsImported(added.packs, added.characters),
        ),
      ),
    );
  }

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
  Widget build(BuildContext context) => BlocConsumer<CastBloc, CastState>(
    // Once for each import, however much it held.
    listenWhen: (was, now) => was.lastImport != now.lastImport,
    listener: _sayImported,
    buildWhen: whenChanged((cast) => (cast.characters, cast.packs, cast.loading)),
    builder: (context, state) {
      final l10n = AppLocalizations.of(context);
      return Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 9, 12, 8),
              child: AreaHeading(
                label: ModuleLabel(number: '03', label: l10n.areaPacks),
                actions: [
                  TextButton.icon(
                    key: const ValueKey('charactersImport'),
                    onPressed: () => _import(context),
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: Text(l10n.charactersImport),
                    style: TextButton.styleFrom(foregroundColor: context.colors.mutedInk),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('packsAdd'),
                    onPressed: () => context.read<CastBloc>().add(PackAdded(l10n.packsNewName)),
                    icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                    label: Text(l10n.packsAdd),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
              child: state.packs.isEmpty
                  ? Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 20,
                          color: context.colors.mutedInk,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(l10n.packsEmpty)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final pack in state.packs) ...[
                          CharacterPackArea(
                            key: ValueKey(pack.id),
                            pack: pack,
                            members: state.membersOf(pack),
                            onRename: (name) =>
                                context.read<CastBloc>().add(PackRenamed(pack.id, name)),
                            onExport: _exporter(context, pack, state.membersOf(pack)),
                            onDelete: () => _confirmDelete(context, pack),
                            onDrop: (drag) => context.read<CastBloc>().add(
                              CardPacked(pack.id, drag.character.id),
                            ),
                            onRemoveMember: (character) => context.read<CastBloc>().add(
                              CardUnpacked(pack.id, character.id),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      );
    },
  );
}
