// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../dashboard/cubits/settings_cubit.dart';

/// Whether the game is silenced altogether while the screen is read.
///
/// This session has no ear in the game -- the text comes off the screen --
/// so the game may go quiet rather than merely be turned down, which is
/// what the live screen offers instead.
class SilenceWhileReadingSwitch extends StatelessWidget {
  const SilenceWhileReadingSwitch({super.key, required this.settings, required this.locked});

  final AppSettings settings;

  /// A session is running, and keeps what it started with.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Switch(
              value: settings.silenceWhileReading,
              onChanged: locked
                  ? null
                  : (value) => context.read<SettingsCubit>().update(
                      settings.copyWith(silenceWhileReading: value),
                    ),
            ),
            const SizedBox(width: 6),
            Flexible(child: Text(l10n.silenceWhileReading)),
          ],
        ),
        const SizedBox(height: 4),
        Text(l10n.silenceWhileReadingNote, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
