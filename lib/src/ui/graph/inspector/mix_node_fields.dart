// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../data/services/playback_scheduler.dart';
import '../../dashboard/cubits/settings_bloc.dart';
import '../canvas/pipeline_facts.dart';
import 'inspector_note.dart';
import 'inspector_toggle.dart';

/// The mix node's panel: whether lines of different speakers may overlap.
class MixNodeFields extends StatelessWidget {
  const MixNodeFields({super.key, required this.facts});

  final PipelineFacts facts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = facts.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InspectorToggle(
          label: l10n.voiceOverlap,
          value: settings.overlapVoices,
          enabled: !facts.running,
          onChanged: (value) => context.read<SettingsBloc>().add(
            SettingsChanged(settings.copyWith(overlapVoices: value)),
          ),
        ),
        InspectorNote(text: l10n.voiceOverlapNote),
        InspectorNote(text: l10n.pipelineMixNote(overlappingVoices)),
      ],
    );
  }
}
