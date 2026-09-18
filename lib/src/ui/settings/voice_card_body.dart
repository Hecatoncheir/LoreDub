// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../../domain/model_selection.dart';
import '../dashboard/cubits/settings_cubit.dart';
import '../theme.dart';
import 'overlap_voices_controls.dart';
import 'voice_bank_controls.dart';
import 'voice_choice_field.dart';

/// What the voice card holds: the mode, and under it only what that mode
/// leaves to set.
class VoiceCardBody extends StatelessWidget {
  const VoiceCardBody({
    super.key,
    required this.selection,
    required this.voiceBankSize,
    required this.running,
    required this.spokenVoice,
  });

  final ModelSelection selection;
  final int voiceBankSize;
  final bool running;

  /// The voice the running session last spoke in, if it has.
  final String? spokenVoice;

  static const _note = TextStyle(color: LoreDubPalette.mutedInk, fontSize: 12);

  /// Which voice the automatic choice actually settled on, so it is not a
  /// silent decision — the same courtesy the detected language gets on the
  /// live screen. With one voice for every line there is nothing to say.
  String? _speaking(AppLocalizations l10n) {
    final voice = spokenVoice;
    if (voice == null) return null;
    return switch (selection.voiceMode) {
      VoiceMode.chosen => null,
      VoiceMode.original => l10n.voiceOriginalSpeaking(voice),
      VoiceMode.automatic => l10n.voiceSpeaking(voice),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = selection.settings;
    final mode = selection.voiceMode;
    final converterInstalled = selection.voiceConverter?.installed ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<VoiceMode>(
          segments: [
            ButtonSegment(
              value: VoiceMode.automatic,
              label: Text(l10n.voiceAutomatic),
              enabled: selection.canFollowSpeaker,
            ),
            ButtonSegment(value: VoiceMode.chosen, label: Text(l10n.voiceFixed)),
            ButtonSegment(value: VoiceMode.original, label: Text(l10n.voiceOriginal)),
          ],
          selected: {mode},
          onSelectionChanged: running
              ? null
              : (picked) =>
                    context.read<SettingsCubit>().update(settings.withVoiceMode(picked.first)),
        ),
        if (mode == VoiceMode.original) ...[
          const SizedBox(height: 10),
          Text(
            converterInstalled ? l10n.voiceOriginalNote : l10n.voiceOriginalMissing,
            style: converterInstalled ? _note : _note.copyWith(color: LoreDubPalette.warning),
          ),
        ],
        // The converter is what hears who is speaking, so remembering the
        // characters is on offer wherever it is installed — with the
        // original voice it also keeps their timbre.
        if (converterInstalled && mode != VoiceMode.chosen) ...[
          const SizedBox(height: 12),
          VoiceBankControls(settings: settings, size: voiceBankSize, running: running),
        ],
        if (!selection.canFollowSpeaker) ...[
          const SizedBox(height: 10),
          Text(l10n.voiceUnavailable, style: _note),
        ],
        if (selection.picksVoiceByHand && selection.availableVoices.isNotEmpty) ...[
          const SizedBox(height: 14),
          VoiceChoiceField(selection: selection, running: running),
        ],
        // With one voice for every line there is nobody to tell apart.
        if (mode != VoiceMode.chosen) ...[
          const SizedBox(height: 12),
          OverlapVoicesControls(settings: settings, running: running),
        ],
        if (_speaking(l10n) case final speaking?) ...[
          const SizedBox(height: 10),
          Text(speaking, style: _note),
        ],
      ],
    );
  }
}
