// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../common/file_dialogs.dart';
import '../../../l10n/app_localizations.dart';
import '../../domain/character.dart';
import '../common/confirm_dialog.dart';
import 'character_tile.dart';
import 'character_tile_actions.dart';
import 'character_tile_model.dart';
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
    final location = await context.read<FileDialogs>().saveJson('$name.json');
    if (location == null) return;
    await cubit.export(location, [character]);
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

  /// The name of the card standing in for this one; a card deleted since
  /// leaves the substitution showing as nobody in particular.
  String? _readerName() {
    final reader = character.voicedBy;
    if (reader == null) return null;
    for (final other in state.characters) {
      if (other.id == reader) return other.name;
    }
    return null;
  }

  CharacterTileModel _model(CharactersCubit cubit) {
    final id = character.id;
    return CharacterTileModel(
      character: character,
      recording: state.recordingId == id,
      heardSeconds: state.heardSeconds,
      packNames: [
        for (final pack in state.packs)
          if (pack.holds(id)) pack.name,
      ],
      packs: state.packs,
      readerName: _readerName(),
      playing: state.playingId == id,
      previewing: state.previewingId == id,
      carriesTimbre: cubit.carriesTimbre,
      dubbing: dubbing,
      building: state.buildingId == id,
      built: state.builtId == id ? state.built : null,
    );
  }

  CharacterTileActions _actions(BuildContext context, CharactersCubit cubit) {
    final id = character.id;
    final canPreview = state.canPreview(dubbing: dubbing, speechInstalled: cubit.canPreview);
    final takesFiles = state.takesFiles(dubbing: dubbing, converterInstalled: cubit.canRecord);
    return CharacterTileActions(
      onRename: (name) => cubit.rename(id, name),
      onDelete: () => _confirmDelete(context),
      onRecord: switch (state.recordActionFor(id)) {
        RecordAction.start => () => cubit.startRecording(id),
        RecordAction.stop => cubit.stopRecording,
        null => null,
      },
      onPlay: state.canPlayClip(id) ? () => cubit.playClip(id) : null,
      onPreview: canPreview ? () => cubit.preview(id) : null,
      onStopSound: cubit.stopSounding,
      onExport: character.vector.isEmpty ? null : () => _export(context),
      onFilesDropped: takesFiles ? (paths) => cubit.voiceFromFiles(id, paths) : null,
      onFileInPack: (packId) => cubit.addToPack(packId, id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CharactersCubit>();
    return CharacterTile(model: _model(cubit), actions: _actions(context, cubit));
  }
}
