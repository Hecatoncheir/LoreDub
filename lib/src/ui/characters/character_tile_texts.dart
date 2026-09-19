// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../../l10n/app_localizations.dart';
import 'character_tile_model.dart';

/// What a character tile says, in the interface language.
class CharacterTileTexts {
  const CharacterTileTexts(this.l10n, this.model);

  final AppLocalizations l10n;
  final CharacterTileModel model;

  String _gender() => switch (model.character.gender) {
    'male' => l10n.voiceGenderMale,
    'female' => l10n.voiceGenderFemale,
    _ => l10n.charactersGenderUnknown,
  };

  /// What the card has of a voice: the seconds ticking by while it records,
  /// or what its recording came to, or that it has none yet.
  String voice() {
    if (model.recording) {
      return model.heardSeconds > 0
          ? l10n.charactersHeard(model.heardSeconds.toStringAsFixed(1))
          : l10n.charactersRecording;
    }
    if (model.character.vector.isEmpty) return l10n.charactersNoVoice;
    return l10n.charactersVoiceKept(model.character.seconds.toStringAsFixed(1), _gender());
  }

  /// What the card says about the recordings it was just built from: how
  /// many held a voice, how closely they agreed, and what was left out. One
  /// recording agrees with itself, so its number is not shown.
  String building() {
    final built = model.built;
    if (model.building || built == null) return l10n.charactersBuilding;
    return [
      _agreement(),
      if (built.skipped.isNotEmpty) l10n.charactersBuiltSkipped(built.skipped.length),
    ].join(' · ');
  }

  String _agreement() {
    final built = model.built!;
    if (!built.together) return l10n.charactersBuiltApart;
    if (built.used <= 1) return l10n.charactersBuiltFromOne;
    return l10n.charactersBuiltFrom(built.used, built.agreement.toStringAsFixed(2));
  }

  /// What the clip button says: stop, nothing to play, or play.
  String playTooltip({required bool canPlay}) {
    if (model.playing) return l10n.charactersStopSound;
    return canPlay ? l10n.charactersPlayClip : l10n.charactersNoClip;
  }

  /// What the sample button says: what it will do, or what it waits for.
  String previewTooltip({required bool canPreview}) {
    if (model.previewing) return l10n.charactersStopSound;
    if (model.dubbing) return l10n.charactersPreviewWhileDubbing;
    if (!canPreview) return l10n.charactersPreviewNeedsModel;
    return model.carriesTimbre ? l10n.charactersPreviewVoice : l10n.charactersPreviewPlain;
  }
}
