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

  group('language pairs', () {
    final translation = translationModelFor('ru')!;
    final speech = speechModelFor('ru')!;

    LanguagePair russianWith(List<ModelInstallState> models) =>
        ModelSelection(models: models, settings: const AppSettings()).languagePairs.firstWhere(
          (pair) => pair.language == 'ru',
        );

    test('pairs each language with its translator and voice, in catalogue order', () {
      final pairs = selectionWith(const AppSettings()).languagePairs;

      expect(pairs.map((pair) => pair.language), ['ru', 'de', 'es', 'fr', 'uk']);
      for (final pair in pairs) {
        expect(pair.translation?.model.kind, ModelKind.translation, reason: pair.language);
        expect(pair.speech?.model.kind, ModelKind.speech, reason: pair.language);
      }
    });

    test('counts as installed only with both halves on disk', () {
      final half = russianWith([
        ModelInstallState(model: translation, installed: true),
        ModelInstallState(model: speech),
      ]);

      expect(half.installed, isFalse);
      expect(half.progress, isNull, reason: 'nothing is downloading');
      expect(half.downloadBytes, translation.downloadBytes + speech.downloadBytes);
    });

    test('shows one share for the pair while a half downloads', () {
      final pair = russianWith([
        ModelInstallState(model: translation, installed: true),
        ModelInstallState(model: speech, progress: 0.5, paused: true),
      ]);
      final expected =
          (translation.downloadBytes + speech.downloadBytes * 0.5) /
          (translation.downloadBytes + speech.downloadBytes);

      expect(pair.progress, closeTo(expected, 1e-9));
      expect(pair.paused, isTrue);
    });
  });

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

  group('telling the characters apart', () {
    final remembering = const AppSettings(voiceBank: true);

    test('hears who is speaking without re-voicing, once the converter is there', () {
      final selection = selectionWith(remembering);

      expect(selection.tracksSpeakers, isTrue);
      expect(selection.clonesVoice, isFalse, reason: 'the timbre stays where it was');
      expect(selection.needsVoiceConverter, isTrue);
      expect(selection.keepsVoiceBank, isTrue);
    });

    test('cannot hear anyone without the converter', () {
      final selection = selectionWith(remembering, converter: false);

      expect(selection.tracksSpeakers, isFalse);
      expect(selection.needsVoiceConverter, isFalse);
      expect(selection.requiredModelsInstalled, isTrue, reason: 'it is not needed to start');
    });

    test('leaves a fixed voice and subtitle mode alone', () {
      expect(
        selectionWith(remembering.withVoiceMode(VoiceMode.chosen)).tracksSpeakers,
        isFalse,
        reason: 'one voice for every line has nobody to tell apart',
      );
      expect(
        selectionWith(remembering.copyWith(captureMode: CaptureMode.ocr)).tracksSpeakers,
        isFalse,
        reason: 'subtitles have nothing to listen to',
      );
    });

    test('still loads the converter for the original voice with nothing remembered', () {
      final selection = selectionWith(
        const AppSettings().withVoiceMode(VoiceMode.original),
      );

      expect(selection.tracksSpeakers, isFalse);
      expect(selection.needsVoiceConverter, isTrue);
      expect(selection.keepsVoiceBank, isFalse, reason: 'the bank switch is off');
    });
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
