// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../common/module_label.dart';
import '../live/models_needed_notice.dart';
import 'character_cast.dart';
import 'character_packs.dart';
import 'character_session_controls.dart';
import 'characters_layout.dart';

/// The characters screen: the player's cast, and the session their voices
/// are recorded through.
class CharactersPanel extends StatelessWidget {
  const CharactersPanel({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
    child: Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ModuleLabel(
                  number: '01',
                  label: AppLocalizations.of(context).areaVoiceRecording,
                ),
                const SizedBox(height: 14),
                CharacterSessionControls(),
              ],
            ),
          ),
        ),
        ModelsNeededNotice(
          ready: (selection) => selection.voiceConverter?.installed ?? false,
        ),
        const SizedBox(height: 16),
        // The cast on the left, the packs beside it on the right: a card is
        // carried across rather than down a scroll, and both ends of the
        // journey stay in sight the whole way. A window too narrow to hold
        // the two side by side puts the packs back underneath, where a drag
        // is longer but possible.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth < CharactersLayout.packsBesideWidth
                ? ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      CharacterCast(),
                      const SizedBox(height: 16),
                      CharacterPacks(),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Each side scrolls on its own, so reaching for a pack
                      // does not move the cards under the pointer.
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [CharacterCast()],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: (constraints.maxWidth * 0.36).clamp(340.0, 480.0),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [CharacterPacks()],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    ),
  );
}
