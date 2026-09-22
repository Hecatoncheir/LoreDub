// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/model_catalog.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/model_selection.dart';
import 'package:lore_dub/src/domain/spoken_language.dart';

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

      expect(pairs.map((pair) => pair.language), ['ru', 'en']);
      for (final pair in pairs) {
        expect(pair.speech?.model.kind, ModelKind.speech, reason: pair.language);
        // English is half a pair on purpose: whisper hands it over already.
        if (pair.language == untranslatedDubbingLanguage) {
          expect(pair.translation, isNull);
          continue;
        }
        expect(pair.translation?.model.kind, ModelKind.translation, reason: pair.language);
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

    test('leaves a fixed voice alone', () {
      expect(
        selectionWith(remembering.withVoiceMode(VoiceMode.chosen)).tracksSpeakers,
        isFalse,
        reason: 'one voice for every line has nobody to tell apart',
      );
    });

    test('still loads the converter for the original voice with nothing remembered', () {
      final selection = selectionWith(
        const AppSettings(voiceBank: false).withVoiceMode(VoiceMode.original),
      );

      expect(selection.tracksSpeakers, isFalse);
      expect(selection.needsVoiceConverter, isTrue);
      expect(selection.keepsVoiceBank, isFalse, reason: 'the bank switch was turned off');
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

  group('the screen', () {
    /// What the page would offer, written as it reads: the text's language,
    /// and where the dubbing is another, an arrow to it.
    List<String> offered(ModelSelection selection) => [
      for (final languages in selection.screenLanguages)
        languages.text == languages.dubbing
            ? languages.text
            : '${languages.text}->${languages.dubbing}',
    ];

    /// Every package on disk but [missing].
    List<ModelInstallState> without(ModelPackage? missing) => [
      for (final state in installed())
        ModelInstallState(model: state.model, installed: state.model != missing),
    ];

    test('offers every voice on disk as it is, then English translated into one', () {
      expect(offered(selectionWith(const AppSettings())), ['ru', 'en', 'en->ru']);
    });

    test('offers no translation without its translator, nor a language without its voice', () {
      expect(
        offered(
          ModelSelection(
            models: without(translationModelFor('ru')),
            settings: const AppSettings(targetLanguage: 'en'),
          ),
        ),
        ['ru', 'en'],
      );
      expect(
        offered(
          ModelSelection(
            models: without(speechModelFor('ru')),
            settings: const AppSettings(targetLanguage: 'en'),
          ),
        ),
        ['en'],
      );
      expect(
        offered(
          ModelSelection(models: without(speechModelFor('ru')), settings: const AppSettings()),
        ),
        ['en', 'en->ru'],
        reason: 'the choice stands on the list once its voice is gone',
      );
    });

    test(
      'translates English text into a dubbing language that is not English, and nothing else',
      () {
        expect(selectionWith(const AppSettings(targetLanguage: 'ru')).screenTranslates, isTrue);
        expect(
          selectionWith(const AppSettings(targetLanguage: 'ru', screenLanguage: 'ru'))
              .screenTranslates,
          isFalse,
          reason: 'Russian text is voiced as it is',
        );
        expect(selectionWith(const AppSettings(targetLanguage: 'en')).screenTranslates, isFalse);
      },
    );

    test('needs the voice it reads in, and the translator only where it translates', () {
      const russian = AppSettings(targetLanguage: 'ru', screenLanguage: 'ru');

      expect(
        ModelSelection(
          models: without(translationModelFor('ru')),
          settings: russian,
        ).screenModelsInstalled,
        isTrue,
      );
      expect(
        ModelSelection(
          models: without(translationModelFor('ru')),
          settings: const AppSettings(targetLanguage: 'ru'),
        ).screenModelsInstalled,
        isFalse,
        reason: 'English text needs the translator',
      );
      expect(
        ModelSelection(
          models: without(speechModelFor('ru')),
          settings: russian,
        ).screenModelsInstalled,
        isFalse,
      );
    });
  });

  group('voice mode', () {
    test('runs the automatic choice where the package can follow the speaker', () {
      final selection = selectionWith(const AppSettings(automaticVoice: true));

      expect(selection.canFollowSpeaker, isTrue);
      expect(selection.voiceMode, VoiceMode.automatic);
      expect(selection.picksVoiceByHand, isFalse);
    });

    test('shows a choice it cannot honour as the one that replaces it', () {
      const settings = AppSettings(automaticVoice: true);
      final bare = ModelSelection(models: const [], settings: settings);

      expect(bare.voiceMode, VoiceMode.chosen);
      expect(bare.picksVoiceByHand, isTrue);
    });

    test('picks the base of the original voice by hand when nothing follows the speaker', () {
      const settings = AppSettings(originalVoice: true);

      expect(selectionWith(settings).picksVoiceByHand, isFalse);
      expect(ModelSelection(models: const [], settings: settings).picksVoiceByHand, isTrue);
    });
  });
}
