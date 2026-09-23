// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/model_catalog.dart';
import 'package:lore_dub/src/domain/model_package.dart';

void main() {
  ModelPackage speechFor(String language) => speechModelFor(language)!;

  test('splits a package into the voices of each gender', () {
    final russian = modelCatalog.firstWhere((model) => model.id == 'vosk-ru-0.9');

    expect(russian.voicesOf(VoiceGender.male), ['male_0', 'male_1']);
    expect(russian.voicesOf(VoiceGender.female), ['female_1']);
  });

  test('offers to follow the speaker only with both genders on hand', () {
    expect(speechFor('ru').canFollowSpeaker, isTrue);
    const menOnly = ModelPackage(
      id: 'men-only',
      artifacts: [],
      kind: ModelKind.speech,
      voices: [VoiceOption('a', gender: VoiceGender.male)],
    );
    expect(menOnly.canFollowSpeaker, isFalse);
  });

  test('names a gender for every voice it lists', () {
    for (final model in modelCatalog) {
      if (model.kind != ModelKind.speech) continue;
      for (final voice in model.voices) {
        expect(
          voice.gender,
          isNot(VoiceGender.unknown),
          reason: '${model.id}/${voice.id} was listed without a measured gender',
        );
      }
    }
  });

  test('keeps the default voice inside the package that names it', () {
    for (final model in modelCatalog) {
      if (model.kind != ModelKind.speech || model.voices.isEmpty) continue;
      expect(
        model.voices.map((voice) => voice.id),
        contains(model.speaker),
        reason: '${model.id} defaults to a voice it does not ship',
      );
    }
  });

  test('says nothing about a package with no voices listed', () {
    const bare = ModelPackage(id: 'bare-xx', artifacts: [], kind: ModelKind.speech);

    expect(bare.canFollowSpeaker, isFalse);
    expect(bare.voicesOf(VoiceGender.male), isEmpty);
  });
}
