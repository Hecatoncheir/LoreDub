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
import '../dashboard/cubits/cast_bloc.dart';
import '../dashboard/cubits/voice_capture_bloc.dart';

/// One card of the cast, wired to what can be done to it right now.
///
/// Which of its buttons work is the state's to say (`canPlayClip`,
/// `canPreview`, `recordActionFor`, `takesFiles`); this only hands the
/// answers to the tile and the presses back to the two blocs: what is done
/// to the card is the cast's, what is done with its voice the capture's.
class CastCard extends StatelessWidget {
  const CastCard({
    super.key,
    required this.character,
    required this.cast,
    required this.capture,
    required this.dubbing,
  });

  final Character character;
  final CastState cast;
  final VoiceCaptureState capture;

  /// A dubbing session holds the worker.
  final bool dubbing;

  Future<void> _export(BuildContext context) async {
    final cast = context.read<CastBloc>();
    final name = character.name.trim().isEmpty ? 'character' : character.name;
    final location = await context.read<FileDialogs>().saveJson('$name.json');
    if (location == null) return;
    cast.add(CastExported(location, [character]));
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cast = context.read<CastBloc>();
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmRemoval(
      context,
      title: l10n.charactersDeleteTitle,
      message: l10n.charactersDeleteMessage(character.name),
      cancelLabel: l10n.charactersDeleteCancel,
      confirmLabel: l10n.charactersDeleteConfirm,
    );
    if (confirmed) cast.add(CardRemoved(character.id));
  }

  /// The name of the card standing in for this one; a card deleted since
  /// leaves the substitution showing as nobody in particular.
  String? _readerName() {
    final reader = character.voicedBy;
    if (reader == null) return null;
    for (final other in cast.characters) {
      if (other.id == reader) return other.name;
    }
    return null;
  }

  CharacterTileModel _model(VoiceCaptureBloc voices) {
    final id = character.id;
    return CharacterTileModel(
      character: character,
      recording: capture.recordingId == id,
      heardSeconds: capture.heardSeconds,
      packNames: [
        for (final pack in cast.packs)
          if (pack.holds(id)) pack.name,
      ],
      packs: cast.packs,
      readerName: _readerName(),
      playing: capture.playingId == id,
      previewing: capture.previewingId == id,
      carriesTimbre: voices.carriesTimbre,
      dubbing: dubbing,
      building: capture.buildingId == id,
      built: capture.builtId == id ? capture.built : null,
    );
  }

  CharacterTileActions _actions(BuildContext context, VoiceCaptureBloc voices) {
    final id = character.id;
    final cards = context.read<CastBloc>();
    final canPreview = capture.canPreview(dubbing: dubbing, speechInstalled: voices.canPreview);
    final takesFiles = capture.takesFiles(dubbing: dubbing, converterInstalled: voices.canRecord);
    return CharacterTileActions(
      onRename: (name) => cards.add(CardRenamed(id, name)),
      onDelete: () => _confirmDelete(context),
      onRecord: switch (capture.recordActionFor(id)) {
        RecordAction.start => () => voices.add(RecordingStarted(id)),
        RecordAction.stop => () => voices.add(const RecordingStopped()),
        null => null,
      },
      onPlay: capture.canPlayClip(id) ? () => voices.add(ClipPlayed(id)) : null,
      onPreview: canPreview ? () => voices.add(SampleAsked(id)) : null,
      onStopSound: () => voices.add(const SoundStopped()),
      onExport: character.vector.isEmpty ? null : () => _export(context),
      onFilesDropped: takesFiles ? (paths) => voices.add(VoiceFilesDropped(id, paths)) : null,
      onFileInPack: (packId) => cards.add(CardPacked(packId, id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final voices = context.read<VoiceCaptureBloc>();
    return CharacterTile(model: _model(voices), actions: _actions(context, voices));
  }
}
