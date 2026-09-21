// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../common/module_label.dart';
import '../dashboard/cubits/session_bloc.dart';
import '../dashboard/cubits/settings_cubit.dart';
import 'compute_device_card.dart';
import 'hotkeys_card.dart';
import 'interface_language_card.dart';
import 'model_directory_card.dart';
import 'paired_cards.dart';
import 'proxy_card.dart';
import 'python_card.dart';
import 'scale_card.dart';
import 'theme_card.dart';
import 'settings_area.dart';
import 'settings_layout.dart';

/// The whole settings screen: five areas of cards, in the order a player
/// meets them — what is heard, how it sounds, what drives it, and at the
/// foot where the parts come from and where they are kept.
///
/// Each group is announced the way the other screens number their areas,
/// and stands off further from its neighbour than the cards inside it do.
/// The grouping was a gap alone before, and the same gap the cards within a
/// group already kept, so eleven cards read as one list and the interface
/// language sat level with the path to Python. The compute card, the voice
/// card and the model directory listen to the downloads themselves, so a
/// runtime arriving does not redraw the whole page.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<SettingsCubit, SettingsState>(
    builder: (context, state) => BlocSelector<SessionBloc, SessionState, bool>(
      selector: (pipeline) => pipeline.running,
      builder: (context, running) {
        final l10n = AppLocalizations.of(context);
        final settings = state.settings;
        return ListView(
          key: const ValueKey('settingsList'),
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
          children: [
            ModuleLabel(number: '01', label: l10n.settingsGroupInterface),
            const SizedBox(height: SettingsLayout.cardGap),
            PairedCards(
              first: InterfaceLanguageCard(settings: settings),
              second: ScaleCard(settings: settings),
            ),
            const SizedBox(height: SettingsLayout.cardGap),
            ThemeCard(settings: settings),
            const SizedBox(height: SettingsLayout.cardGap),
            HotkeysCard(settings: settings, running: running),
            const SizedBox(height: SettingsLayout.groupGap),
            ModuleLabel(number: '02', label: l10n.settingsGroupCompute),
            const SizedBox(height: SettingsLayout.cardGap),
            const ComputeDeviceCard(),
            const SizedBox(height: SettingsLayout.groupGap),
            // Where the parts come from, and where they are kept: two areas
            // of their own rather than one drawer holding everything a player
            // only opens when something is broken.
            PairedCards(
              sameHeight: false,
              stackedGap: SettingsLayout.groupGap,
              first: SettingsArea(
                number: '03',
                label: l10n.settingsGroupDownloads,
                children: const [ProxyCard()],
              ),
              second: SettingsArea(
                number: '04',
                label: l10n.settingsGroupPaths,
                children: const [
                  PythonCard(),
                  SizedBox(height: SettingsLayout.cardGap),
                  ModelDirectoryCard(),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
