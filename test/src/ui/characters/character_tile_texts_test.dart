// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/l10n/app_localizations.dart';
import 'package:lore_dub/src/domain/built_voice.dart';
import 'package:lore_dub/src/domain/character.dart';
import 'package:lore_dub/src/ui/characters/character_tile_model.dart';
import 'package:lore_dub/src/ui/characters/character_tile_texts.dart';

void main() {
  late AppLocalizations l10n;
  const guard = Character(id: 'a1', name: 'Guard', vector: [0.1], seconds: 4.2);

  setUp(() async => l10n = await AppLocalizations.delegate.load(const Locale('en')));

  CharacterTileTexts texts(CharacterTileModel model) => CharacterTileTexts(l10n, model);

  test('counts the seconds while recording, and says what was kept after', () {
    const recording = CharacterTileModel(character: guard, recording: true, heardSeconds: 1.5);

    expect(texts(recording).voice(), l10n.charactersHeard('1.5'));
    expect(texts(const CharacterTileModel(character: guard)).voice(), contains('4.2'));
    expect(
      texts(
        const CharacterTileModel(
          character: Character(id: 'b', name: 'B', vector: []),
        ),
      ).voice(),
      l10n.charactersNoVoice,
    );
  });

  test('tells how the files a voice was built from agreed', () {
    const apart = BuiltVoice(used: 3, together: false);
    const one = BuiltVoice(used: 1, skipped: ['x.png']);

    expect(
      texts(const CharacterTileModel(character: guard, built: apart)).building(),
      l10n.charactersBuiltApart,
    );
    expect(
      texts(const CharacterTileModel(character: guard, built: one)).building(),
      '${l10n.charactersBuiltFromOne} · ${l10n.charactersBuiltSkipped(1)}',
    );
    expect(
      texts(const CharacterTileModel(character: guard, building: true, built: one)).building(),
      l10n.charactersBuilding,
    );
  });

  test('says what the sample waits for rather than only that it cannot run', () {
    const idle = CharacterTileModel(character: guard);

    expect(texts(idle).previewTooltip(canPreview: true), l10n.charactersPreviewVoice);
    expect(texts(idle).previewTooltip(canPreview: false), l10n.charactersPreviewNeedsModel);
    expect(
      texts(const CharacterTileModel(character: guard, dubbing: true)).previewTooltip(
        canPreview: false,
      ),
      l10n.charactersPreviewWhileDubbing,
    );
  });
}
