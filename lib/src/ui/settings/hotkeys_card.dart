// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../common/setting_card.dart';
import 'hotkey_row.dart';

/// The combinations Windows hands the application wherever the pointer is.
/// They are the player's own way in, so they stand with the interface rather
/// than beside the hardware the models run on.
class HotkeysCard extends StatelessWidget {
  const HotkeysCard({super.key, required this.settings, required this.running});

  final AppSettings settings;

  /// A session holds the combinations it registered, so they wait for it.
  final bool running;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingCard(
      title: l10n.settingsHotkeys,
      subtitle: l10n.hotkeysNote,
      child: Column(
        children: [
          for (final (index, action) in HotkeyAction.values.indexed) ...[
            if (index > 0) const SizedBox(height: 10),
            HotkeyRow(action: action, settings: settings, enabled: !running),
          ],
        ],
      ),
    );
  }
}
