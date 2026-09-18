// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/character.dart';
import '../common/confirm_dialog.dart';
import '../dashboard/character_tiles.dart';
import '../dashboard/cubits/characters_cubit.dart';

/// One card of the cast, wired to what can be done to it right now.
///
/// Which of its buttons work is the state's to say (`canPlayClip`,
/// `canPreview`, `recordActionFor`, `takesFiles`); this only hands the
/// answers to the tile and the presses back to the cubit.
class CastCard extends StatelessWidget {
  const CastCard({
    super.key,
    required this.character,
    required this.state,
    required this.dubbing,
  });

  final Character character;
  final CharactersState state;

  /// A dubbing session holds the worker.
  final bool dubbing;

  Future<void> _export(BuildContext context) async {
    final cubit = context.read<CharactersCubit>();
    final name = character.name.trim().isEmpty ? 'character' : character.name;
    final location = await getSaveLocation(suggestedName: '$name.json');
    if (location == null) return;
    await cubit.export(location.path, [character]);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<CharactersCubit>();
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmRemoval(
      context,
      title: l10n.charactersDeleteTitle,
      message: l10n.charactersDeleteMessage(character.name),
      cancelLabel: l10n.charactersDeleteCancel,
      confirmLabel: l10n.charactersDeleteConfirm,
    );
    if (confirmed) await cubit.remove(character.id);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CharactersCubit>();
    final id = character.id;
    final canPreview = state.canPreview(dubbing: dubbing, speechInstalled: cubit.canPreview);
    final takesFiles = state.takesFiles(dubbing: dubbing, converterInstalled: cubit.canRecord);
    return CharacterTile(
      character: character,
      recording: state.recordingId == id,
      heardSeconds: state.heardSeconds,
      packNames: [
        for (final pack in state.packs)
          if (pack.holds(id)) pack.name,
      ],
      cast: [
        for (final other in state.characters)
          if (other.id != id) other,
      ],
      onRename: (name) => cubit.rename(id, name),
      playing: state.playingId == id,
      onPlay: state.canPlayClip(id) ? () => cubit.playClip(id) : null,
      previewing: state.previewingId == id,
      onStopSound: cubit.stopSounding,
      carriesTimbre: cubit.carriesTimbre,
      dubbing: dubbing,
      onPreview: canPreview ? () => cubit.preview(id) : null,
      onRecord: switch (state.recordActionFor(id)) {
        RecordAction.start => () => cubit.startRecording(id),
        RecordAction.stop => cubit.stopRecording,
        null => null,
      },
      building: state.buildingId == id,
      built: state.builtId == id ? state.built : null,
      onFilesDropped: takesFiles ? (paths) => cubit.voiceFromFiles(id, paths) : null,
      onExport: character.vector.isEmpty ? null : () => _export(context),
      onDelete: () => _confirmDelete(context),
    );
  }
}
