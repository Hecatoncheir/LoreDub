// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../common/labeled_switch.dart';
import '../dashboard/cubits/settings_cubit.dart';

/// Whether lines of different speakers may play over one another, with what
/// that means written under it.
class OverlapVoicesControls extends StatelessWidget {
  const OverlapVoicesControls({super.key, required this.settings, required this.running});

  final AppSettings settings;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledSwitch(
          value: settings.overlapVoices,
          label: l10n.voiceOverlap,
          onChanged: running
              ? null
              : (value) =>
                    context.read<SettingsCubit>().update(settings.copyWith(overlapVoices: value)),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.voiceOverlapNote,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
