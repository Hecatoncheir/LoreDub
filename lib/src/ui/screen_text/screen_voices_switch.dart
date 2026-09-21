// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../dashboard/cubits/settings_bloc.dart';
import '../dashboard/dashboard_context.dart';

/// Whether the game is listened to while its subtitles are read, so a line
/// is read in the voice of whoever was speaking as it appeared.
///
/// Nothing of that sound is recognized -- the words come off the frame --
/// and it is the converter that hears who is speaking, so the switch waits
/// for it the way the original voice does.
class ScreenVoicesSwitch extends StatelessWidget {
  const ScreenVoicesSwitch({super.key, required this.settings, required this.locked});

  final AppSettings settings;

  /// A session is running, and keeps what it started with.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final converter = context.selection.voiceConverter;
    final ready = converter?.installed ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Switch(
              key: const ValueKey('screenVoices'),
              value: settings.screenVoices && ready,
              onChanged: locked || !ready
                  ? null
                  : (value) => context.read<SettingsBloc>().add(
                      SettingsChanged(
                        settings.copyWith(screenVoices: value),
                      ),
                    ),
            ),
            const SizedBox(width: 6),
            Flexible(child: Text(l10n.screenVoices)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          ready ? l10n.screenVoicesNote : l10n.voiceOriginalMissing,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
