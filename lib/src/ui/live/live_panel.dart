// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../common/module_label.dart';
import 'scene_voices_card.dart';
import 'source_controls.dart';
import 'start_checklist.dart';
import 'transcript_card.dart';
import 'live_layout.dart';

/// The Эфир screen: where the sound comes from and in which language it is
/// dubbed, the start button, and below them the transcript and the voices
/// of the scene.
class LivePanel extends StatelessWidget {
  const LivePanel({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    // The transcript takes what the cards above it leave, and in a short
    // window -- a compact layout with its navigation along the foot, a
    // checklist still to be worked through -- that was less than the card
    // needs for its own header. Under the floor the screen scrolls instead.
    builder: (context, constraints) => constraints.maxHeight >= LiveLayout.minHeight
        ? _content(context)
        : SingleChildScrollView(
            child: SizedBox(height: LiveLayout.minHeight, child: _content(context)),
          ),
  );

  Widget _content(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
    child: Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ModuleLabel(number: '01', label: AppLocalizations.of(context).areaGameInput),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) => SourceControls(
                    compact: constraints.maxWidth < LiveLayout.wideSourceRowWidth,
                  ),
                ),
              ],
            ),
          ),
        ),
        StartChecklist(),
        const SizedBox(height: 16),
        // The transcript and the voices of the scene stand side by side
        // where there is room; a narrow window stacks them, the transcript
        // keeping whatever height is left.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth >= LiveLayout.sceneBesideTranscriptWidth
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: TranscriptCard()),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: LiveLayout.sceneVoicesWidth,
                        child: SceneVoicesCard(),
                      ),
                    ],
                  )
                // Shares of what is left rather than a fixed height. Under a
                // card's worth of room the transcript takes it all: two
                // headers and nothing under them would serve nobody.
                : constraints.maxHeight < LiveLayout.sceneStackedMinHeight
                ? TranscriptCard()
                : Column(
                    children: [
                      Expanded(flex: 3, child: TranscriptCard()),
                      const SizedBox(height: 16),
                      Expanded(flex: 2, child: SceneVoicesCard()),
                    ],
                  ),
          ),
        ),
      ],
    ),
  );
}
