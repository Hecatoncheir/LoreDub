// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/model_catalog.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/spoken_language.dart';

void main() {
  test('recognition is a single package that serves every language', () {
    final recognition = modelCatalog.where((model) => model.kind == ModelKind.recognition);

    expect(recognition, hasLength(1));
    expect(recognition.single.id, whisperModelId);
    expect(recognition.single.language, isNull);
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

  test('keeps the identifiers the Russian pair was downloaded under', () {
    // These name folders on disk; renaming them would silently ask everyone
    // to download half a gigabyte again.
    expect(translationModelFor('ru')?.id, 'bergamot-en-ru');
    expect(speechModelFor('ru')?.id, 'silero-ru-v5.3');
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
}
