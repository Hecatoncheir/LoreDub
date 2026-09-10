// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/model_catalog.dart';
import 'package:lore_dub/src/domain/model_package.dart';

void main() {
  ModelPackage speechFor(String language) => speechModelFor(language)!;

  test('splits a package into the voices of each gender', () {
    final russian = speechFor('ru');

    expect(russian.voicesOf(VoiceGender.male), ['aidar', 'eugene']);
    expect(russian.voicesOf(VoiceGender.female), ['baya', 'kseniya', 'xenia']);
  });

  test('offers to follow the speaker only with both genders on hand', () {
    expect(speechFor('ru').canFollowSpeaker, isTrue);
    expect(speechFor('de').canFollowSpeaker, isTrue);
    expect(speechFor('fr').canFollowSpeaker, isTrue);
    // Measured: every Spanish voice is a man's, and Ukrainian ships one.
    expect(speechFor('es').canFollowSpeaker, isFalse);
    expect(speechFor('uk').canFollowSpeaker, isFalse);
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
    const bare = ModelPackage(id: 'silero-xx', artifacts: [], kind: ModelKind.speech);

    expect(bare.canFollowSpeaker, isFalse);
    expect(bare.voicesOf(VoiceGender.male), isEmpty);
  });
}
