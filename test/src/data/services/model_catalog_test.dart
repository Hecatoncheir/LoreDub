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

  test('dubs into Russian and nothing else', () {
    // Every other language went with Silero, whose voices are CC BY-NC.
    expect(dubbingLanguages, ['ru']);
    expect(translationModelFor('ru'), isNotNull);
    expect(speechModelFor('ru'), isNotNull);
  });

  test('has no English voice, so nothing is dubbed without the translator', () {
    // Whisper hands English over whatever the game speaks; with a voice for
    // it the translator could be left out, and without one it cannot.
    expect(speechModelFor(untranslatedDubbingLanguage), isNull);
    expect(dubbingLanguages, isNot(contains(untranslatedDubbingLanguage)));
  });

  test('reads Russian with Vosk, pinned file by file with its NOTICE', () {
    final speech = modelCatalog.where((model) => model.kind == ModelKind.speech).toList();
    expect(speech.map((model) => model.id), ['vosk-ru-0.9']);
    final vosk = speech.single;

    // The pipeline names a speech package by its first file, and the worker
    // reads the package from the directory it sits in.
    expect(vosk.primaryFileName, 'model.onnx');
    for (final artifact in vosk.artifacts) {
      expect(artifact.byteSize, isNotNull, reason: artifact.fileName);
      expect(artifact.hash, hasLength(64), reason: artifact.fileName);
      expect(artifact.url.toString(), startsWith(voskVoiceRelease), reason: artifact.fileName);
    }
    // Apache 2.0 travels with the weights.
    expect(vosk.artifacts.map((artifact) => artifact.fileName), contains('NOTICE'));
  });

  test('names a default voice among the ones the package lists', () {
    for (final model in modelCatalog.where((model) => model.kind == ModelKind.speech)) {
      expect(model.speaker, isNotEmpty, reason: model.id);
      expect(model.voices.map((voice) => voice.id), contains(model.speaker), reason: model.id);
    }
  });

  test('keeps the identifier the Russian translator was downloaded under', () {
    // Identifiers name folders on disk, so changing one asks everyone to
    // download again.
    expect(translationModelFor('ru')?.id, 'opus-mt-tc-big-en-zle');
    expect(speechModelFor('ru')?.id, 'vosk-ru-0.9');
  });

  test('names the target language for a translator that serves several', () {
    // opus-mt-tc-big-en-zle covers Russian, Ukrainian and Belarusian, and
    // picks between them from a token in front of the text.
    expect(translationModelFor('ru')?.translationPrefix, '>>rus<<');
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
          // github.com is this project's own releases: the translator is
          // converted here and the Vosk voice laid out as files, rather than
          // fetched as their authors published them.
          anyOf('huggingface.co', 'github.com'),
          reason: model.id,
        );
      }
    }
  });

  test('pins every file of a translator we converted ourselves', () {
    // Nothing published upstream can be pinned harder than its author pins
    // it, and OPUS-MT publishes no digests. What we convert we measure, so
    // every file of it carries a size and a SHA-256.
    for (final model in modelCatalog) {
      if (model.kind != ModelKind.translation) continue;
      if (!model.artifacts.first.url.host.contains('github.com')) continue;
      for (final artifact in model.artifacts) {
        expect(artifact.byteSize, greaterThan(0), reason: '${model.id}/${artifact.fileName}');
        expect(artifact.hash, isNotNull, reason: '${model.id}/${artifact.fileName}');
      }
      expect(
        model.artifacts.map((artifact) => artifact.fileName),
        containsAll(['model.bin', 'source.spm', 'vocab.json', 'NOTICE']),
        reason: '${model.id} needs the model, its tokenizer and its attribution',
      );
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
