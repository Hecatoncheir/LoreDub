// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/repositories/glossary_repository.dart';
import 'package:lore_dub/src/data/repositories/settings_repository.dart';
import 'package:lore_dub/src/data/services/native_engine_service.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/domain/glossary.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/glossary_bloc.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/failure_cubit.dart';

void main() {
  const fire = GlossaryEntry(
    kind: GlossaryKind.phrase,
    source: 'Fire in the hole!',
    reading: 'Ложись!',
  );
  const reloading = GlossaryEntry(
    kind: GlossaryKind.phrase,
    source: 'Reloading!',
    reading: 'Перезарядка!',
  );
  const megaton = GlossaryEntry(kind: GlossaryKind.name, source: 'Megaton', reading: 'Мегатон');
  final fallout = GlossaryPack(id: 'p1', name: 'Fallout', entryKeys: [megaton.packKey]);

  late _Disk disk;
  late _Banner banner;

  setUp(() {
    disk = _Disk();
    banner = _Banner();
  });

  GlossaryBloc build() => GlossaryBloc(disk, banner, clock: () => DateTime(2026, 9, 21));

  /// A state holding [entries]; a glossary is not compared by value.
  Matcher holding(List<GlossaryEntry> entries) =>
      isA<GlossaryState>().having((state) => state.glossary.entries, 'entries', entries);

  /// What is on disk as the screen opens on it.
  GlossaryState opened(Glossary glossary) => GlossaryState(glossary: glossary, loaded: true);

  blocTest<GlossaryBloc, GlossaryState>(
    'reads what is written down, and says a file that cannot be read',
    setUp: () => disk.failure = StateError('unreadable'),
    build: build,
    act: (bloc) => bloc.add(const GlossaryOpened()),
    expect: () => [const GlossaryState(loaded: true)],
    verify: (_) => expect(banner.reported, isA<StateError>()),
  );

  blocTest<GlossaryBloc, GlossaryState>(
    'writes an entry down trimmed, and keeps it',
    build: build,
    act: (bloc) => bloc.add(
      const GlossaryEntryWritten(
        GlossaryEntry(
          kind: GlossaryKind.phrase,
          source: ' Fire in the hole! ',
          reading: 'Ложись! ',
        ),
      ),
    ),
    expect: () => [
      holding([fire]),
    ],
    verify: (_) => expect(disk.saved.single.entries, [fire]),
  );

  blocTest<GlossaryBloc, GlossaryState>(
    'passes a phrase over rather than reading it',
    build: build,
    seed: () => opened(const Glossary(entries: [reloading])),
    act: (bloc) => bloc.add(
      const GlossaryEntryWritten(
        GlossaryEntry(
          kind: GlossaryKind.phrase,
          source: 'Reloading!',
          reading: 'Перезарядка!',
          silent: true,
        ),
      ),
    ),
    verify: (bloc) =>
        expect(bloc.state.glossary.match(GlossaryKind.phrase, 'Reloading!')?.silent, isTrue),
  );

  blocTest<GlossaryBloc, GlossaryState>(
    'makes a pack empty and switched off, so it narrows nothing',
    build: build,
    seed: () => opened(const Glossary(entries: [fire])),
    act: (bloc) => bloc.add(const GlossaryPackAdded('Новый пакет')),
    verify: (bloc) {
      final pack = bloc.state.glossary.packs.single;
      expect(pack.name, 'Новый пакет');
      expect(pack.entryKeys, isEmpty);
      expect(pack.active, isFalse);
      expect(bloc.state.glossary.inUse.entries, [fire]);
    },
  );

  blocTest<GlossaryBloc, GlossaryState>(
    'narrows what is in use to the pack switched on',
    build: build,
    seed: () => opened(Glossary(entries: const [fire, megaton], packs: [fallout])),
    act: (bloc) => bloc.add(const GlossaryPackSwitched('p1', active: true)),
    verify: (bloc) => expect(bloc.state.glossary.inUse.entries, [megaton]),
  );

  blocTest<GlossaryBloc, GlossaryState>(
    'throws a pack away and keeps its entries',
    build: build,
    seed: () => opened(Glossary(entries: const [megaton], packs: [fallout])),
    act: (bloc) => bloc.add(const GlossaryPackRemoved('p1')),
    verify: (bloc) {
      expect(bloc.state.glossary.packs, isEmpty);
      expect(bloc.state.glossary.entries, [megaton]);
    },
  );

  blocTest<GlossaryBloc, GlossaryState>(
    'files an entry in a pack and takes it out again',
    build: build,
    seed: () => opened(Glossary(entries: const [fire, megaton], packs: [fallout])),
    act: (bloc) => bloc
      ..add(const GlossaryEntryFiled(fire, into: 'p1'))
      ..add(const GlossaryEntryUnfiled(megaton, from: 'p1')),
    verify: (bloc) => expect(bloc.state.glossary.packs.single.entryKeys, [fire.packKey]),
  );

  blocTest<GlossaryBloc, GlossaryState>(
    'answers edits in the order they came, each from the one before',
    build: build,
    act: (bloc) => bloc
      ..add(const GlossaryEntryWritten(fire))
      ..add(const GlossaryEntryWritten(reloading))
      ..add(const GlossaryEntryRemoved(GlossaryKind.phrase, 'Fire in the hole!')),
    verify: (bloc) {
      expect(bloc.state.glossary.entries, [reloading]);
      expect(disk.saved.map((glossary) => glossary.entries.length), [1, 2, 1]);
    },
  );

  blocTest<GlossaryBloc, GlossaryState>(
    'puts back what is on disk when a write fails',
    setUp: () => disk.failure = StateError('disk full'),
    build: build,
    seed: () => opened(const Glossary(entries: [fire])),
    act: (bloc) => bloc.add(const GlossaryEntryWritten(reloading)),
    expect: () => [
      holding([fire, reloading]),
      holding([fire]),
    ],
    verify: (_) => expect(banner.reported, isA<StateError>()),
  );

  blocTest<GlossaryBloc, GlossaryState>(
    'merges what a file held and says how much, keeping a pack switched as it was',
    setUp: () => disk.incoming = Glossary(
      entries: const [megaton, reloading],
      packs: [
        GlossaryPack(id: 'p1', name: 'Fallout 3', entryKeys: [megaton.packKey], active: true),
      ],
    ),
    build: build,
    seed: () => opened(Glossary(entries: const [fire], packs: [fallout])),
    act: (bloc) => bloc.add(const GlossaryFilesImported(['C:/games/vault.json'])),
    verify: (bloc) {
      expect(disk.read, ['C:/games/vault.json']);
      expect(bloc.state.lastImport, const GlossaryImport(number: 1, entries: 2, packs: 1));
      expect(bloc.state.glossary.entries, hasLength(3));
      final pack = bloc.state.glossary.packs.single;
      expect(pack.name, 'Fallout 3', reason: 'the file wins');
      expect(pack.active, isFalse, reason: 'but not over which glossary is read against');
    },
  );

  blocTest<GlossaryBloc, GlossaryState>(
    'says nothing of an import it could not read, and reports it',
    setUp: () => disk.readFailure = StateError('not a glossary'),
    build: build,
    act: (bloc) => bloc.add(const GlossaryFilesImported(['C:/games/broken.json'])),
    expect: () => const <GlossaryState>[],
    verify: (_) => expect(banner.reported, isA<StateError>()),
  );

  blocTest<GlossaryBloc, GlossaryState>(
    'writes one pack out with the entries it names',
    build: build,
    seed: () => opened(Glossary(entries: const [fire, megaton], packs: [fallout])),
    act: (bloc) => bloc.add(const GlossaryPackExported('C:/out/fallout.json', 'p1')),
    verify: (_) {
      final (destination, written) = disk.exported.single;
      expect(destination, 'C:/out/fallout.json');
      expect(written.entries, [megaton]);
    },
  );
}

/// The glossary's file with no disk behind it.
class _Disk extends GlossaryRepository {
  _Disk() : super(SettingsRepository(SettingsService()), NativeEngineService());

  final saved = <Glossary>[];
  final exported = <(String, Glossary)>[];
  List<String> read = const [];
  Glossary incoming = Glossary.empty;

  /// What loading and saving fail with, if they are to.
  Object? failure;

  /// What reading the player's files fails with, if it is to.
  Object? readFailure;

  @override
  Future<Glossary> load() async {
    if (failure case final failure?) throw failure;
    return Glossary.empty;
  }

  @override
  Future<void> save(Glossary glossary) async {
    if (failure case final failure?) throw failure;
    saved.add(glossary);
  }

  @override
  Future<void> exportTo(String destination, Glossary glossary) async =>
      exported.add((destination, glossary));

  @override
  Future<Glossary> readFiles(List<String> sources) async {
    read = sources;
    if (readFailure case final failure?) throw failure;
    return incoming;
  }
}

class _Banner implements FailureSink {
  Object? reported;

  @override
  void report(Object? error) => reported = error;
}
