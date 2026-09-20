// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/character.dart';
import '../../domain/pipeline_state.dart';
import '../dashboard/cubits/characters_cubit.dart';
import '../speaker_names.dart';
import '../theme.dart';
import 'scene_voice_row.dart';

/// Every voice the session has heard, each named as the cast knows it and
/// with who reads it now.
class SceneVoicesList extends StatelessWidget {
  const SceneVoicesList({super.key, required this.speakers});

  final List<SceneSpeaker> speakers;

  @override
  Widget build(BuildContext context) =>
      BlocSelector<CharactersCubit, CharactersState, List<Character>>(
        selector: (characters) => characters.characters,
        builder: (context, characters) {
          final l10n = AppLocalizations.of(context);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            // The card grows with this list and scrolls inside itself once
            // it has grown as far as it may.
            shrinkWrap: true,
            children: [
              Text(
                characters.isEmpty
                    ? l10n.sceneVoiceNoCharacters
                    : '${l10n.sceneVoicesNote} ${l10n.voicesOnTheGraph}',
                style: TextStyle(fontSize: 12, color: context.colors.mutedInk),
              ),
              const SizedBox(height: 6),
              for (final speaker in speakers)
                SceneVoiceRow(
                  speaker: speaker,
                  name: speakerName(l10n, speaker.key, characters),
                  readsAs: replacementName(speaker.key, characters),
                ),
            ],
          );
        },
      );
}
