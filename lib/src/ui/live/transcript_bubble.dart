// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'speak_again_button.dart';

import 'package:flutter/material.dart';

import '../../domain/character.dart';
import '../../domain/pipeline_state.dart';
import '../../../l10n/app_localizations.dart';
import '../speaker_names.dart';
import '../theme.dart';
import 'bubble_tail_painter.dart';
import 'correct_line_button.dart';
import 'latency_badge.dart';

/// One recognized phrase, shaped like the speech bubble on the application
/// icon: the text on the dark signal surface, and the time it took beside the
/// tail on the orange accent.
class TranscriptBubble extends StatelessWidget {
  const TranscriptBubble({
    super.key,
    required this.entry,
    this.characters = const [],
    this.onCorrect,
    this.onSpeakAgain,
  });

  static const double _tailInset = 28;
  static const Size _tailSize = Size(26, 14);

  final TranscriptEntry entry;

  /// The cast, so a line matched to a card is named rather than numbered,
  /// and so a line read by another card can say whose voice it was.
  final List<Character> characters;

  /// What to do with a correction the player writes for this line. Null
  /// where there is nothing to write it into.
  final void Function(TranscriptEntry entry, String reading, {bool silent})? onCorrect;

  /// Reads this line again. Null where the session no longer holds what it
  /// was read as -- an older line, or one that was never voiced.
  final VoidCallback? onSpeakAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final original = entry.original.isEmpty ? entry.english : entry.original;
    final speaker = entry.speaker;
    final readAs = speaker == null ? null : replacementName(speaker, characters);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (speaker != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 5),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    speakerName(l10n, speaker, characters),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.monoCaption.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (readAs != null) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      l10n.sceneVoiceReplaced(readAs),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.monoCaption.copyWith(color: context.colors.accent),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        Container(
          // Sized by its text, with enough width left for the tail to stay
          // under the bubble even for a two-word reply.
          constraints: const BoxConstraints(minWidth: 80),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 15),
          decoration: BoxDecoration(
            color: context.colors.deep,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (original.isNotEmpty) ...[
                Text(
                  original,
                  style: TextStyle(
                    color: context.colors.onDeep.withValues(alpha: 0.62),
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 7),
              ],
              // A line the player silenced has no translation to show, and
              // saying so is the point: the quiet was asked for rather than
              // something the pipeline lost.
              if (entry.silenced)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.volume_off_rounded,
                      size: 16,
                      color: context.colors.onDeepMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppLocalizations.of(context).transcriptSilenced,
                      style: TextStyle(
                        color: context.colors.onDeepMuted,
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        height: 1.25,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  entry.translated,
                  style: TextStyle(
                    color: context.colors.onDeep,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
            ],
          ),
        ),
        Row(
          // Top-aligned: the badge is taller than the tail, and centring the
          // row would lift the tail off the bottom edge of the bubble.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: _tailInset),
            CustomPaint(
              size: _tailSize,
              painter: BubbleTailPainter(color: context.colors.deep),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LatencyBadge(milliseconds: entry.latency.inMilliseconds),
            ),
            // Only where there is an English line to file the correction
            // under: what came back in the dubbing language was never
            // translated, and has nothing for the glossary to match on.
            if (onCorrect != null && entry.english.trim().isNotEmpty)
              CorrectLineButton(entry: entry, onCorrect: onCorrect!),
            // A line goes by while the player is looking at the game;
            // here it can be heard again.
            if (onSpeakAgain != null && entry.spoken != null)
              SpeakAgainButton(onPressed: onSpeakAgain!),
          ],
        ),
      ],
    );
  }
}
