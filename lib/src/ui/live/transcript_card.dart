// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/character.dart';
import '../../domain/glossary.dart';
import '../../domain/pipeline_state.dart';
import '../../../l10n/app_localizations.dart';
import '../dashboard/cubits/characters_cubit.dart';
import '../dashboard/cubits/glossary_cubit.dart';
import '../dashboard/cubits/pipeline_cubit.dart';
import '../dashboard/cubits/settings_cubit.dart';
import '../common/module_label.dart';
import '../common/clear_list_button.dart';
import 'empty_transcript.dart';
import 'transcript_bubble.dart';

/// What the running session heard, newest first.
class TranscriptCard extends StatelessWidget {
  const TranscriptCard({
    super.key,
    this.number = '02',
    this.label,
    this.fromScreen = false,
  });

  /// Which area of its screen this is, and what it is called there. Live
  /// dubbing lists what it heard second; the screen session lists what the
  /// frame gained third, after the controls and the frame itself.
  final String number;

  /// Null on Live, where it is the transcript of what was heard.
  final String? label;

  /// Whether the lines came off the screen rather than out of the game's
  /// sound, which is all the empty state needs to name the right route.
  final bool fromScreen;

  @override
  Widget build(BuildContext context) =>
      BlocSelector<PipelineCubit, LivePipelineState, List<TranscriptEntry>>(
        selector: (pipeline) => pipeline.transcript,
        builder: (context, transcript) =>
            BlocSelector<CharactersCubit, CharactersState, List<Character>>(
              selector: (characters) => characters.characters,
              builder: (context, cast) => Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Padding(
                      // Tighter than a bare label row would need: the button has
                      // to fit without making the header taller than it was.
                      padding: const EdgeInsets.fromLTRB(20, 9, 12, 8),
                      child: Row(
                        children: [
                          ModuleLabel(
                            number: number,
                            label: label ?? AppLocalizations.of(context).areaTranscript,
                          ),
                          const Spacer(),
                          ClearListButton(
                            tooltip: AppLocalizations.of(context).transcriptClearTooltip,
                            onPressed: transcript.isEmpty
                                ? null
                                : context.read<PipelineCubit>().clearTranscript,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: transcript.isEmpty
                          ? BlocBuilder<SettingsCubit, SettingsState>(
                              builder: (context, settings) => EmptyTranscript(
                                targetLanguage: settings.settings.targetLanguage,
                                fromScreen: fromScreen,
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                              itemCount: transcript.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 14),
                              itemBuilder: (context, index) => TranscriptBubble(
                                entry: transcript[index],
                                characters: cast,
                                // A line is corrected where it was heard going
                                // wrong, which is the only moment the player knows
                                // it did. The glossary screen is then the list of
                                // what was collected rather than a place to
                                // remember to visit.
                                onCorrect: (entry, reading, {silent = false}) =>
                                    context.read<GlossaryCubit>().write(
                                      GlossaryEntry(
                                        kind: GlossaryKind.phrase,
                                        source: entry.english,
                                        reading: reading,
                                        silent: silent,
                                      ),
                                    ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
      );
}
