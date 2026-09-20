// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../common/module_label.dart';
import 'live_layout.dart';
import 'dubbing_cards.dart';
import 'live_transcript_area.dart';
import 'source_controls.dart';
import 'start_checklist.dart';

/// What the Эфир screen holds, at whatever height [LivePanel] gives it: the
/// source card, the checklist, and the transcript area under them.
class LiveContent extends StatelessWidget {
  const LiveContent({super.key});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const ValueKey('liveList'),
    padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
        // How the dubbing sounds, beside the button that starts it rather
        // than on the settings screen: the volume of the game under it,
        // the pace it is read at, and the voice reading.
        ModuleLabel(number: '02', label: AppLocalizations.of(context).settingsGroupDubbing),
        const SizedBox(height: 12),
        DubbingCards(),
        const SizedBox(height: 16),
        const LiveTranscriptArea(),
      ],
    ),
  );
}
