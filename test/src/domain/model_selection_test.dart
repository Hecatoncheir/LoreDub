// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/model_catalog.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/model_selection.dart';

void main() {
  /// Every package on disk, except the voice converter unless asked for.
  List<ModelInstallState> installed({bool converter = true}) => [
    for (final model in modelCatalog)
      ModelInstallState(
        model: model,
        installed: converter || model.kind != ModelKind.voiceConversion,
      ),
  ];

  ModelSelection selectionWith(AppSettings settings, {bool converter = true}) => ModelSelection(
    models: installed(converter: converter),
    settings: settings,
  );

  test('needs the voice converter only once the original voice is asked for', () {
    expect(
      selectionWith(const AppSettings(), converter: false).requiredModelsInstalled,
      isTrue,
      reason: 'the other modes never touch it',
    );

    final original = const AppSettings().withVoiceMode(VoiceMode.original);
    expect(selectionWith(original, converter: false).requiredModelsInstalled, isFalse);
    expect(selectionWith(original).requiredModelsInstalled, isTrue);
  });

  test('never clones in subtitle mode, which has no audio to take a timbre from', () {
    final settings = const AppSettings(
      captureMode: CaptureMode.ocr,
    ).withVoiceMode(VoiceMode.original);
    final selection = selectionWith(settings, converter: false);

    expect(selection.canUseOriginalVoice, isFalse);
    expect(selection.clonesVoice, isFalse);
    expect(selection.requiredModelsInstalled, isTrue, reason: 'the converter is not needed here');
  });

  test('lays the original timbre over a base voice that follows the speaker', () {
    // Picked by hand first, then switched to the original voice: the base
    // still follows the speaker, so the converter has less to move.
    final settings = const AppSettings(automaticVoice: false).withVoiceMode(VoiceMode.original);

    expect(selectionWith(settings).followsSpeaker, isTrue);
  });

  test('reads the stored flags back as one mode', () {
    expect(const AppSettings().voiceMode, VoiceMode.automatic);
    expect(const AppSettings(automaticVoice: false).voiceMode, VoiceMode.chosen);
    expect(const AppSettings(originalVoice: true).voiceMode, VoiceMode.original);
    expect(
      const AppSettings(originalVoice: true).withVoiceMode(VoiceMode.chosen).originalVoice,
      isFalse,
    );
  });
}
