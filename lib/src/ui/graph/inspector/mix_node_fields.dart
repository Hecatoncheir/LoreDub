// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/pipeline_graph.dart';
import '../../../domain/speech_pace.dart';
import '../../settings/bloc/settings_bloc.dart';
import '../canvas/pipeline_facts.dart';
import 'inspector_note.dart';
import 'inspector_toggle.dart';

/// The mix node's panel: whether lines of different speakers may overlap.
///
/// On the Screen page's scheme there is nothing to choose: the screen is
/// read a line at a time, so no two voices ever meet in the mix.
class MixNodeFields extends StatelessWidget {
  const MixNodeFields({super.key, required this.facts, this.scheme = PipelineScheme.live});

  final PipelineFacts facts;
  final PipelineScheme scheme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = facts.settings;
    if (scheme == PipelineScheme.screen) return InspectorNote(text: l10n.pipelineScreenMixNote);
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
