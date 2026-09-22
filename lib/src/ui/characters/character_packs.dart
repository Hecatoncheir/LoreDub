// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../common/file_dialogs.dart';
import '../../domain/pack_filter.dart';
import '../../../l10n/app_localizations.dart';
import '../theme.dart';
import '../common/dashboard_context.dart';
import '../common/module_label.dart';
import '../common/area_heading.dart';
import '../common/pack_filter_field.dart';
import 'character_pack_list.dart';
import 'bloc/cast_bloc.dart';

/// The packs: named areas cards are dropped into, handed on and thrown away
/// as a group. Throwing one away leaves the cards in the cast — the player
/// recorded them, and only the grouping was ever the pack's.
class CharacterPacks extends StatefulWidget {
  const CharacterPacks({super.key});

  @override
  State<CharacterPacks> createState() => _CharacterPacksState();
}

class _CharacterPacksState extends State<CharacterPacks> {
  /// What the shelf is narrowed to by name, kept here rather than in the
  /// field: a pack made or loaded is one the player means to see, and the
  /// field is emptied for it.
  final _named = TextEditingController();

  @override
  void dispose() {
    _named.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final cast = context.read<CastBloc>();
    final chosen = await context.read<FileDialogs>().openJson();
    if (chosen.isEmpty) return;
    _named.clear();
    cast.add(CastImported(chosen));
  }

  void _add(String name) {
    _named.clear();
    context.read<CastBloc>().add(PackAdded(name));
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
                    onPressed: _import,
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: Text(l10n.charactersImport),
                    style: TextButton.styleFrom(foregroundColor: context.colors.mutedInk),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('packsAdd'),
                    onPressed: () => _add(l10n.packsNewName),
                    icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                    label: Text(l10n.packsAdd),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.packs.isNotEmpty) ...[
                    PackFilterField(key: const ValueKey('packsFilter'), controller: _named),
                    const SizedBox(height: 14),
                  ],
                  ListenableBuilder(
                    listenable: _named,
                    builder: (context, _) =>
                        CharacterPackList(state: state, filter: PackFilter(_named.text)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
