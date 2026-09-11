// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/model_catalog.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/spoken_language.dart';

void main() {
  test('offers several recognition models, none tied to a language', () {
    final recognition = modelCatalog.where((model) => model.kind == ModelKind.recognition);

    expect(recognition.length, greaterThan(1), reason: 'the model is a choice');
    expect(recognition.first.id, whisperModelId, reason: 'the smallest is the default');
    for (final model in recognition) {
      expect(model.language, isNull, reason: model.id);
      expect(model.version, isNotNull, reason: '${model.id} needs a name to show');
    }
  });

  test('names the recognition model that cannot translate speech', () {
    // large-v3-turbo was fine-tuned without translation data. Marking it is
    // what stops the pipeline asking it for English it was never taught.
    final transcribeOnly = modelCatalog.where(
      (model) => model.kind == ModelKind.recognition && !model.translatesSpeech,
    );

    expect(transcribeOnly.map((model) => model.id), ['whisper-large-v3-turbo-q5']);
  });

  test('every dubbing language has both a translator and a voice', () {
    expect(dubbingLanguages, isNotEmpty);
    for (final language in dubbingLanguages) {
      expect(translationModelFor(language), isNotNull, reason: language);
      expect(speechModelFor(language), isNotNull, reason: language);
    }
  });

  test('every voice names the speaker to synthesize with', () {
    for (final model in modelCatalog.where((model) => model.kind == ModelKind.speech)) {
      expect(model.speaker, isNotNull, reason: model.id);
      expect(model.speaker, isNotEmpty, reason: model.id);
      expect(model.artifacts, hasLength(1), reason: 'the worker is handed one file');
      expect(model.primaryFileName, endsWith('.pt'), reason: model.id);
    }
  });

  test('keeps the identifier the Russian voice was downloaded under', () {
    // Identifiers name folders on disk, so changing one asks everyone to
    // download again. The voice keeps its name; the translator deliberately
    // does not — it was replaced by the Tatoeba-Challenge model, which is
    // worth the second download.
    expect(speechModelFor('ru')?.id, 'silero-ru-v5.3');
    expect(translationModelFor('ru')?.id, 'opus-mt-tc-big-en-zle');
  });

  test('names the target language for a translator that serves several', () {
    // opus-mt-tc-big-en-zle covers Russian, Ukrainian and Belarusian, and
    // picks between them from a token in front of the text.
    expect(translationModelFor('ru')?.translationPrefix, '>>rus<<');
    expect(translationModelFor('de')?.translationPrefix, isNull);
  });

  test('offers a readable name for every dubbing language', () {
    for (final language in dubbingLanguages) {
      expect(isSupportedSpokenLanguage(language), isTrue, reason: language);
    }
  });

  test('states a size for every artifact so progress can be shown', () {
    for (final model in modelCatalog) {
      for (final artifact in model.artifacts) {
        expect(artifact.byteSize, isNotNull, reason: '${model.id} / ${artifact.fileName}');
        expect(artifact.byteSize, greaterThan(0), reason: '${model.id} / ${artifact.fileName}');
      }
    }
  });

  test('downloads each artifact from the host it belongs to', () {
    for (final model in modelCatalog) {
      for (final artifact in model.artifacts) {
        expect(artifact.url.scheme, 'https', reason: model.id);
        expect(
          artifact.url.host,
          anyOf('huggingface.co', 'models.silero.ai'),
          reason: model.id,
        );
      }
    }
  });

  test('lists each package once', () {
    final ids = modelCatalog.map((model) => model.id).toList();

    expect(ids.toSet(), hasLength(ids.length));
  });

  test('offers one voice converter for every language, pinned byte for byte', () {
    final converters = modelCatalog.where((model) => model.kind == ModelKind.voiceConversion);

    expect(converters.map((model) => model.id), [voiceConverterModelId]);
    final converter = converters.single;
    expect(converter.language, isNull, reason: 'the timbre is moved the same way for any language');
    expect(
      converter.artifacts.map((artifact) => artifact.fileName),
      containsAll(['checkpoint.pth', 'config.json']),
    );
    for (final artifact in converter.artifacts) {
      expect(
        artifact.hash,
        hasLength(64),
        reason: '${artifact.fileName} runs as code in the worker',
      );
    }
  });
}
