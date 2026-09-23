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

  test('dubs into Russian and English and nothing else', () {
    // The other languages went with Silero, whose voices are CC BY-NC.
    expect(dubbingLanguages, ['ru', 'en']);
    expect(translationModelFor('ru'), isNotNull);
    expect(speechModelFor('ru'), isNotNull);
  });

  test('dubs into English with a voice alone where Marian is the translator', () {
    // Whisper hands English over whatever the game speaks, so the one
    // language that needs no Marian is the one it recognizes into. The
    // language model serves it all the same: it reads the game's own
    // language, and English is one it translates into.
    expect(speechModelFor(untranslatedDubbingLanguage), isNotNull);
    final marian = modelCatalog.where(
      (model) =>
          model.kind == ModelKind.translation &&
          !model.languageModel &&
          model.serves(untranslatedDubbingLanguage),
    );
    expect(marian, isEmpty);
    expect(translationModelFor(untranslatedDubbingLanguage)?.languageModel, isTrue);
    expect(dubbingLanguages, contains(untranslatedDubbingLanguage));
  });

  test('reads each language with one voice, pinned file by file with its NOTICE', () {
    final speech = modelCatalog.where((model) => model.kind == ModelKind.speech).toList();
    expect(speech.map((model) => model.id), ['qwen3-tts-1.7b', 'vosk-ru-0.9', englishVoiceModelId]);
    final releases = {'vosk-ru-0.9': voskVoiceRelease, englishVoiceModelId: kokoroVoiceRelease};

    for (final voice in speech) {
      // Which wrapper reads it is the package's own answer, and its name is
      // what the models screen shows beside the version.
      expect(voice.engine, isNotEmpty, reason: voice.id);
      for (final artifact in voice.artifacts) {
        expect(artifact.byteSize, isNotNull, reason: artifact.fileName);
        expect(artifact.hash, hasLength(64), reason: artifact.fileName);
      }
      if (voice.clonesVoice) {
        // The voice that clones is fetched from its authors' repository as
        // they laid it out, its config first: the worker reads the wrapper
        // off it, where `model.onnx` says nothing.
        expect(voice.primaryFileName, 'config.json', reason: voice.id);
        for (final artifact in voice.artifacts) {
          expect(
            artifact.url.toString(),
            startsWith(qwenVoiceRepository),
            reason: artifact.fileName,
          );
        }
        continue;
      }
      // The pipeline names a speech package by its first file, and the worker
      // reads the package from the directory it sits in.
      expect(voice.primaryFileName, 'model.onnx', reason: voice.id);
      for (final artifact in voice.artifacts) {
        expect(
          artifact.url.toString(),
          startsWith(releases[voice.id]!),
          reason: artifact.fileName,
        );
      }
      // Apache 2.0 travels with the weights we laid out ourselves.
      expect(voice.artifacts.map((artifact) => artifact.fileName), contains('NOTICE'));
    }
  });

  test('offers the voice that clones for both languages, a default voice for each', () {
    final voice = speechModelFor('ru')!;
    expect(voice.id, 'qwen3-tts-1.7b');
    expect(voice.clonesVoice, isTrue);
    expect(voice.servedLanguages, ['ru', 'en']);
    expect(identical(speechModelFor('en'), voice), isTrue);
    // A Russian line read in an English voice would carry its accent, so
    // each language names a voice of its own among the package's.
    expect(voice.speakerFor('ru'), 'ru_female_1');
    expect(voice.speakerFor('en'), 'af_heart');
    for (final language in voice.servedLanguages) {
      expect(voice.voices.map((option) => option.id), contains(voice.speakerFor(language)));
    }
    expect(voice.canFollowSpeaker, isTrue, reason: 'a man and a woman among the fixed voices');
  });

  test('offers the language model first, for every language it dubs into', () {
    final translator = translationModelFor('ru')!;
    expect(translator.id, 'translategemma-4b-q4');
    expect(translator.languageModel, isTrue);
    expect(translator.primaryFileName, endsWith('.gguf'));
    expect(translator.servedLanguages, containsAll(dubbingLanguages));
    expect(translator.translationPrefix, isNull, reason: 'it is told the language by name');
  });

  test('names a default voice among the ones the package lists', () {
    for (final model in modelCatalog.where((model) => model.kind == ModelKind.speech)) {
      expect(model.speaker, isNotEmpty, reason: model.id);
      expect(model.voices.map((voice) => voice.id), contains(model.speaker), reason: model.id);
    }
  });

  test('keeps the identifiers the processor packages were downloaded under', () {
    // Identifiers name folders on disk, so changing one asks everyone to
    // download again. The language model and the voice that clones stand in
    // front of them in the catalogue, so these are what a machine with only
    // the older packages on disk keeps running on.
    final ids = modelCatalog.map((model) => model.id);
    expect(ids, containsAll(['opus-mt-tc-big-en-zle', 'vosk-ru-0.9', englishVoiceModelId]));
    final marian = modelCatalog.firstWhere((model) => model.id == 'opus-mt-tc-big-en-zle');
    expect(marian.serves('ru'), isTrue);
    expect(marian.languageModel, isFalse);
  });

  test('names the target language for a translator that serves several', () {
    // opus-mt-tc-big-en-zle covers Russian, Ukrainian and Belarusian, and
    // picks between them from a token in front of the text.
    final marian = modelCatalog.firstWhere((model) => model.id == 'opus-mt-tc-big-en-zle');
    expect(marian.translationPrefix, '>>rus<<');
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
