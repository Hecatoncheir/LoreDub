// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/character.dart';
import '../../domain/glossary.dart';
import '../../domain/pipeline_state.dart';
import '../glossary/bloc/glossary_bloc.dart';
import '../settings/bloc/settings_bloc.dart';
import 'empty_transcript.dart';
import 'transcript_bubble.dart';
import '../common/bloc/transcript_bloc.dart';

/// What a transcript card holds: the lines, newest first, or the line
/// saying where they will come from while there are none.
class TranscriptLines extends StatelessWidget {
  const TranscriptLines({
    super.key,
    required this.entries,
    required this.characters,
    required this.fromScreen,
    required this.scrolls,
  });

  final List<TranscriptEntry> entries;
  final List<Character> characters;
  final bool fromScreen;

  /// Whether the card hands the list a height to fill. Where the page
  /// scrolls instead, the list is grown to what it holds -- and scrolls
  /// inside that once it has grown as far as the card allows.
  final bool scrolls;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, settings) =>
            EmptyTranscript(settings: settings.settings, fromScreen: fromScreen),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      shrinkWrap: !scrolls,
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) => TranscriptBubble(
        entry: entries[index],
        characters: characters,
        onSpeakAgain: () => context.read<TranscriptBloc>().add(LineSpokenAgain(entries[index])),
        // A line is corrected where it was heard going wrong, which is the
        // only moment the player knows it did. The glossary screen is then
        // the list of what was collected rather than a place to remember to
        // visit.
        onCorrect: (entry, reading, {silent = false}) => context.read<GlossaryBloc>().add(
          GlossaryEntryWritten(
            GlossaryEntry(
              kind: GlossaryKind.phrase,
              source: entry.english,
              reading: reading,
              silent: silent,
            ),
          ),
        ),
      ),
    );
  }
}
