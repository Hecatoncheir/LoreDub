// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:lore_dub/src/data/services/character_service.dart';
import 'package:lore_dub/src/data/services/native_engine_service.dart';
import 'package:lore_dub/src/domain/character.dart';
import 'package:mocktail/mocktail.dart';

/// The cast's files with no disk behind them: the cards, the clips kept
/// beside them, and what an import would read.
class MemoryCharacters extends Fake implements CharacterService {
  CharacterLibrary stored = CharacterLibrary.empty;
  CharacterLibrary incoming = CharacterLibrary.empty;

  /// The clips kept beside the cards, by card.
  final kept = <String, String>{};
  final exported = <(String, CharacterLibrary)>[];

  @override
  Future<String> file() async => 'characters.json';

  @override
  Future<CharacterLibrary> load() async => stored;

  @override
  Future<void> save(CharacterLibrary library) async => stored = library;

  @override
  Future<CharacterLibrary> readFiles(List<String> sources) async => incoming;

  @override
  Future<void> exportTo(String destination, CharacterLibrary library) async =>
      exported.add((destination, library));

  @override
  Future<Set<String>> clips() async => kept.keys.toSet();

  @override
  Future<String?> clipFor(String id) async => kept[id];

  @override
  Future<void> keepClip(String id, String source) async => kept[id] = source;

  @override
  Future<void> removeClip(String id) async => kept.remove(id);
}

/// An engine that only listens to what a running worker would be told about
/// the cast: who reads whom, and which cards are out of the mix.
class TellingEngine extends Fake implements NativeEngineService {
  /// What a running worker was told to read anew, without a restart.
  final told = <(String, String?)>[];

  /// Every time a running worker was told which cards had left the mix.
  final heard = <Set<String>>[];

  @override
  Future<void> voiceCharacterAs(String character, String? target) async =>
      told.add((character, target));

  @override
  Future<void> readAsHeard(Set<String> value) async => heard.add(value);
}
