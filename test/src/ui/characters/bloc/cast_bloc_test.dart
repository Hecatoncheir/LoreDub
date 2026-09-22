// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/repositories/cast_repository.dart';
import 'package:lore_dub/src/domain/character.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/cast_bloc.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/failure_cubit.dart';

import '../../../support/memory_cast.dart';

void main() {
  const guard = Character(id: 'a1', name: 'Стражник', vector: [0.2, 0.4]);
  const smith = Character(id: 'b2', name: 'Кузнец', vector: [0.3]);

  late MemoryCharacters files;
  late TellingEngine engine;
  late CastRepository cast;
  late _Banner banner;

  setUp(() {
    files = MemoryCharacters();
    engine = TellingEngine();
    cast = CastRepository(engine, files);
    banner = _Banner();
  });

  tearDown(() => cast.dispose());

  /// A bloc over [cards] as the disk holds them, the screen opened on them.
  CastBloc over(List<Character> cards, {List<CharacterPack> packs = const []}) {
    files.stored = CharacterLibrary(characters: cards, packs: packs);
    return CastBloc(cast, banner)..add(const CastOpened());
  }

  blocTest<CastBloc, CastState>(
    'adds a card, names it and throws it away again, on disk as on screen',
    build: () => over(const []),
    act: (bloc) async {
      bloc.add(const CardAdded('Новый персонаж'));
      await pumpEventQueue();
      final id = bloc.state.characters.single.id;
      bloc.add(CardRenamed(id, 'Кузнец'));
      await pumpEventQueue();
      expect(files.stored.characters.single.name, 'Кузнец', reason: 'written, not only shown');
      bloc.add(CardRemoved(id));
    },
    verify: (bloc) {
      expect(bloc.state.characters, isEmpty);
      expect(files.stored.characters, isEmpty);
    },
  );

  blocTest<CastBloc, CastState>(
    'takes the clip away with the card',
    setUp: () => files.kept['a1'] = 'clip.wav',
    build: () => over(const [guard]),
    act: (bloc) => bloc.add(const CardRemoved('a1')),
    verify: (_) => expect(files.kept, isEmpty),
  );

  blocTest<CastBloc, CastState>(
    'gives a card another character to be read by, tells a running worker, and takes it back',
    build: () => over(const [guard, smith]),
    act: (bloc) async {
      bloc.add(const CardVoicedAs('a1', 'b2'));
      await pumpEventQueue();
      expect(bloc.state.characters.first.voicedBy, 'b2');
      expect(files.stored.characters.first.voicedBy, 'b2', reason: 'written, not only shown');
      bloc.add(const CardVoicedAs('a1', null));
    },
    verify: (bloc) {
      expect(bloc.state.characters.first.voicedBy, isNull);
      expect(engine.told, [('a1', 'b2'), ('a1', null)]);
    },
  );

  blocTest<CastBloc, CastState>(
    'refuses to read a card by itself, which would say nothing',
    build: () => over(const [guard]),
    act: (bloc) => bloc.add(const CardVoicedAs('a1', 'a1')),
    verify: (bloc) {
      expect(bloc.state.characters.single.voicedBy, isNull);
      expect(engine.told, isEmpty);
    },
  );

  blocTest<CastBloc, CastState>(
    'collects cards into a pack, once each, and lets them out again',
    build: () => over(const [guard, smith]),
    act: (bloc) async {
      bloc.add(const PackAdded('Таверна'));
      await pumpEventQueue();
      final pack = bloc.state.packs.single.id;
      bloc
        ..add(CardPacked(pack, 'a1'))
        ..add(CardPacked(pack, 'b2'))
        // The same card dropped twice is in the pack once.
        ..add(CardPacked(pack, 'a1'));
      await pumpEventQueue();
      expect(bloc.state.packs.single.characterIds, ['a1', 'b2']);
      expect(files.stored.packs.single.name, 'Таверна', reason: 'written, not only shown');
      bloc.add(CardUnpacked(pack, 'a1'));
    },
    verify: (bloc) {
      expect(bloc.state.packs.single.characterIds, ['b2']);
      expect(bloc.state.characters, hasLength(2), reason: 'out of the pack, not the cast');
    },
  );

  blocTest<CastBloc, CastState>(
    'holds one card in as many packs as it was dropped into',
    build: () => over(const [guard]),
    act: (bloc) async {
      bloc
        ..add(const PackAdded('Таверна'))
        ..add(const PackAdded('Пролог'));
      await pumpEventQueue();
      for (final pack in bloc.state.packs) {
        bloc.add(CardPacked(pack.id, 'a1'));
      }
    },
    verify: (bloc) => expect(bloc.state.packs.map((pack) => pack.holds('a1')), [true, true]),
  );

  blocTest<CastBloc, CastState>(
    'throwing a pack away leaves the cards it held',
    build: () => over(
      const [guard],
      packs: const [
        CharacterPack(id: 'p1', name: 'Таверна', characterIds: ['a1']),
      ],
    ),
    act: (bloc) => bloc.add(const PackRemoved('p1')),
    verify: (bloc) {
      expect(bloc.state.packs, isEmpty);
      expect(bloc.state.characters.single.name, 'Стражник');
      expect(files.stored.characters, hasLength(1));
    },
  );

  blocTest<CastBloc, CastState>(
    'a deleted card leaves the packs that held it',
    build: () => over(
      const [guard],
      packs: const [
        CharacterPack(id: 'p1', name: 'Таверна', characterIds: ['a1']),
      ],
    ),
    act: (bloc) => bloc.add(const CardRemoved('a1')),
    verify: (bloc) => expect(bloc.state.packs.single.characterIds, isEmpty),
  );

  blocTest<CastBloc, CastState>(
    'lays imported cards over the ones they came from, and says how many',
    setUp: () => files.incoming = const CharacterLibrary(
      characters: [
        Character(id: 'a1', name: 'Стражник у ворот', vector: [0.9]),
        smith,
      ],
    ),
    build: () => over(const [guard]),
    act: (bloc) => bloc.add(const CastImported(['cast.json'])),
    verify: (bloc) {
      expect(bloc.state.characters.map((card) => card.name), ['Стражник у ворот', 'Кузнец']);
      expect(bloc.state.lastImport, const CastImport(number: 1, characters: 2, packs: 0));
    },
  );

  blocTest<CastBloc, CastState>(
    'an imported pack brings its cards into the cast',
    setUp: () => files.incoming = const CharacterLibrary(
      characters: [
        Character(id: 'c3', name: 'Трактирщик', vector: [0.4]),
        Character(id: 'd4', name: 'Бард', vector: [0.6]),
      ],
      packs: [
        CharacterPack(id: 'p1', name: 'Таверна', characterIds: ['c3', 'd4']),
      ],
    ),
    build: () => over(const []),
    act: (bloc) => bloc.add(const CastImported(['tavern.json'])),
    verify: (bloc) {
      expect(bloc.state.characters.map((card) => card.name), ['Трактирщик', 'Бард']);
      expect(bloc.state.packs.single.characterIds, ['c3', 'd4']);
      expect(bloc.state.lastImport, const CastImport(number: 1, characters: 2, packs: 1));
    },
  );

  blocTest<CastBloc, CastState>(
    'follows a card the canvas gave away, without being told',
    build: () => over(const [guard, smith]),
    act: (bloc) async {
      await pumpEventQueue();
      await cast.voiceAs('a1', 'b2');
    },
    verify: (bloc) => expect(bloc.state.characters.first.voicedBy, 'b2'),
  );

  test('names the cards a pack holds, in the order they were dropped in', () {
    const state = CastState(
      loading: false,
      characters: [guard, smith],
      packs: [
        CharacterPack(id: 'p1', name: 'Таверна', characterIds: ['b2', 'gone', 'a1']),
      ],
    );

    expect(
      state.membersOf(state.packs.single).map((character) => character.name),
      ['Кузнец', 'Стражник'],
      reason: 'an id no card answers to is passed over',
    );
  });
}

class _Banner implements FailureSink {
  Object? reported;

  @override
  void report(Object? error) => reported = error;
}
