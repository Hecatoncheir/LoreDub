// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/app_settings.dart';
import '../../../l10n/app_localizations.dart';
import '../common/labeled_switch.dart';
import '../theme.dart';
import 'bloc/settings_bloc.dart';
import '../common/confirm_dialog.dart';

/// Whether the original voice remembers the characters, how many it has,
/// and a way to forget them. Forgetting cannot be undone, so it is asked.
class VoiceBankControls extends StatelessWidget {
  const VoiceBankControls({
    super.key,
    required this.settings,
    required this.size,
    required this.running,
  });

  final AppSettings settings;
  final int size;
  final bool running;

  Future<void> _confirmClear(BuildContext context) async {
    final settings = context.read<SettingsBloc>();
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmRemoval(
      context,
      title: l10n.voiceBankClearTitle,
      message: l10n.voiceBankClearMessage,
      cancelLabel: l10n.voiceBankClearCancel,
      confirmLabel: l10n.voiceBankClearConfirm,
    );
    if (confirmed) settings.add(const VoiceBankCleared());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledSwitch(
          value: settings.voiceBank,
          label: l10n.voiceBank,
          onChanged: running
              ? null
              : (value) => context.read<SettingsBloc>().add(
                  SettingsChanged(settings.copyWith(voiceBank: value)),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          settings.voiceBank ? l10n.voiceBankOnNote : l10n.voiceBankOffNote,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        // Shown with the switch off too: voices kept earlier are still on
        // disk, and this is where they are given back.
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.voiceBankCount(size),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton.icon(
              // The running worker holds the bank and would write it back.
              onPressed: running || size == 0 ? null : () => _confirmClear(context),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(l10n.voiceBankClear),
              style: TextButton.styleFrom(foregroundColor: context.colors.mutedInk),
            ),
          ],
        ),
      ],
    );
  }
}
