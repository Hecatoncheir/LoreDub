// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/pipeline_state.dart';
import '../theme.dart';

/// One voice of the running scene: who was heard, what they last said, and
/// the character whose voice reads them from now on.
///
/// The row says who the voice is and who reads it. Setting that is the
/// graph's, so that one scheme decides who speaks for whom rather than three
/// screens disagreeing about it.
class SceneVoiceRow extends StatelessWidget {
  const SceneVoiceRow({
    super.key,
    required this.speaker,
    required this.name,
    required this.readsAs,
  });

  final SceneSpeaker speaker;

  /// What to call the voice itself, already resolved to wording.
  final String name;

  /// The name of the character reading this voice, as the graph gave it
  /// away; null when the voice reads itself.
  final String? readsAs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                readsAs == null ? Icons.graphic_eq_rounded : Icons.published_with_changes_rounded,
                size: 16,
                color: readsAs == null ? context.colors.mutedInk : context.colors.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: LoreDubFonts.display,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                l10n.sceneVoiceLines(speaker.lines),
                style: context.textStyles.monoCaption,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            // Placing the voices needs no words, so a row gathered before
            // the dubbing says how much of the voice was heard instead.
            speaker.line.isNotEmpty
                ? speaker.line
                : l10n.sceneVoiceHeardFor(speaker.seconds.toStringAsFixed(1)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 8),
          // Who reads this voice, as the graph wired it. The row shows it
          // and nothing more: the graph is where it is set.
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              key: ValueKey('reads-${speaker.key}'),
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              decoration: BoxDecoration(
                color: context.colors.raised,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                border: Border.all(
                  color: readsAs == null ? context.colors.outline : context.colors.accent,
                ),
              ),
              child: Text(
                readsAs ?? l10n.sceneVoiceAsHeard,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: readsAs == null ? null : FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
