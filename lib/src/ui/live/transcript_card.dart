// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/character.dart';
import '../../domain/pipeline_state.dart';
import '../../../l10n/app_localizations.dart';
import '../dashboard/cubits/characters_cubit.dart';
import '../dashboard/cubits/pipeline_cubit.dart';
import '../common/module_label.dart';
import '../common/clear_list_button.dart';
import 'transcript_body.dart';
import 'transcript_lines.dart';

/// What the running session heard, newest first.
class TranscriptCard extends StatelessWidget {
  const TranscriptCard({
    super.key,
    this.number = '02',
    this.label,
    this.fromScreen = false,
    this.fillsHeight = true,
  });

  /// Which area of its screen this is, and what it is called there. Live
  /// dubbing lists what it heard second; the screen page lists what the
  /// frame gained fifth, after the controls, the snippets and the frame.
  final String number;

  /// Null on Live, where it is the transcript of what was heard.
  final String? label;

  /// Whether the lines came off the screen rather than out of the game's
  /// sound, which is all the empty state needs to name the right route.
  final bool fromScreen;

  /// Whether the card takes the height it is given -- as on Live, where it
  /// has the window to itself -- or grows with what it holds, which is what
  /// the screen page, scrolling as a whole, asks of it.
  final bool fillsHeight;

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
                  mainAxisSize: fillsHeight ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    Padding(
                      // Tighter than a bare label row would need: the button
                      // has to fit without making the header taller.
                      padding: const EdgeInsets.fromLTRB(20, 9, 12, 8),
                      child: Row(
                        children: [
                          Flexible(
                            child: ModuleLabel(
                              number: number,
                              label: label ?? AppLocalizations.of(context).areaTranscript,
                            ),
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
                    TranscriptBody(
                      fillsHeight: fillsHeight,
                      empty: transcript.isEmpty,
                      lines: TranscriptLines(
                        entries: transcript,
                        characters: cast,
                        fromScreen: fromScreen,
                        scrolls: fillsHeight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      );
}
