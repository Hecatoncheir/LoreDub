// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/cast_repository.dart';
import '../../../domain/character.dart';
import '../../../domain/id_source.dart';
import '../../shell/bloc/failure_cubit.dart';

/// How many cards and packs one import read, numbered so that two imports
/// of the same size are still two things to say.
class CastImport extends Equatable {
  const CastImport({required this.number, required this.characters, required this.packs});

  final int number;
  final int characters;
  final int packs;

  @override
  List<Object?> get props => [number, characters, packs];
}

/// The player's cards and the packs they are collected into, as the
/// characters screen shows them.
class CastState extends Equatable {
  const CastState({
    this.characters = const [],
    this.packs = const [],
    this.loading = true,
    this.lastImport,
  });

  final List<Character> characters;

  /// The groups the cards are collected into. A character may be in several
  /// of them, and every character is in the cast whether a pack holds them
  /// or not.
  final List<CharacterPack> packs;

  /// Set until the file has been read once, so an empty screen does not
  /// claim the player has no characters before anyone looked.
  final bool loading;

  /// What the last import read, which the screen says once. Left as it was
  /// by one that failed -- that is reported.
  final CastImport? lastImport;

  /// The cards [pack] holds, in the order they were dropped into it. An id
  /// no card answers to is passed over rather than drawn as a gap.
  List<Character> membersOf(CharacterPack pack) => [
    for (final id in pack.characterIds)
      for (final character in characters)
        if (character.id == id) character,
  ];

  CastState copyWith({
    List<Character>? characters,
    List<CharacterPack>? packs,
    bool? loading,
    CastImport? lastImport,
  }) => CastState(
    characters: characters ?? this.characters,
    packs: packs ?? this.packs,
    loading: loading ?? this.loading,
    lastImport: lastImport ?? this.lastImport,
  );

  @override
  List<Object?> get props => [characters, packs, loading, lastImport];
}

sealed class CastEvent extends Equatable {
  const CastEvent();

  @override
  List<Object?> get props => const [];
}

/// The screen is up: the cards are read, once whoever asks first.
final class CastOpened extends CastEvent {
  const CastOpened();
}

/// Writes one card, the whole cast, or a pack with the cards it holds.
final class CastExported extends CastEvent {
  const CastExported(this.destination, this.characters, {this.pack});

  final String destination;
  final List<Character> characters;
  final CharacterPack? pack;

  @override
  List<Object?> get props => [destination, characters, pack];
}

/// A change to the cards or the packs.
///
/// One kind for all of them, answered one at a time: each is made from the
/// cast the one before it left, and the file is written in the order they
/// were asked for.
sealed class CastEdit extends CastEvent {
  const CastEdit();
}

/// Adds an empty card for the player to name and record.
final class CardAdded extends CastEdit {
  const CardAdded(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}

final class CardRenamed extends CastEdit {
  const CardRenamed(this.id, this.name);

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

/// Reads [id] in [target]'s voice wherever they are recognized, or in their
/// own again when [target] is null. A card cannot be given its own voice,
/// which would say nothing.
final class CardVoicedAs extends CastEdit {
  const CardVoicedAs(this.id, this.target);

  final String id;
  final String? target;

  @override
  List<Object?> get props => [id, target];
}

/// Throws a card away, with the clip it was recorded from, and takes it out
/// of every pack that held it.
final class CardRemoved extends CastEdit {
  const CardRemoved(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// Adds an empty pack for the player to name and drop cards into.
final class PackAdded extends CastEdit {
  const PackAdded(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}

final class PackRenamed extends CastEdit {
  const PackRenamed(this.id, this.name);

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

/// Throws the group away and leaves the cards. The player recorded them;
/// only the grouping was ever the pack's.
final class PackRemoved extends CastEdit {
  const PackRemoved(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// Puts a card in a pack, where a card dropped on a pack lands.
final class CardPacked extends CastEdit {
  const CardPacked(this.packId, this.characterId);

  final String packId;
  final String characterId;

  @override
  List<Object?> get props => [packId, characterId];
}

final class CardUnpacked extends CastEdit {
  const CardUnpacked(this.packId, this.characterId);

  final String packId;
  final String characterId;

  @override
  List<Object?> get props => [packId, characterId];
}

/// Lays imported cards and packs over the ones they came from.
final class CastImported extends CastEdit {
  const CastImported(this.files);

  final List<String> files;

  @override
  List<Object?> get props => [files];
}

final class _CastChanged extends CastEvent {
  const _CastChanged(this.library);

  final CharacterLibrary library;

  @override
  List<Object?> get props => [library];
}

/// The cards and the packs of the characters screen.
///
/// The cast is `CastRepository`'s, which the canvas works on as well; this
/// follows it and writes through it, and what it shows comes back from
/// there rather than from what it asked for -- a screen that emitted what it
/// wrote was a second writer, and its own echo put the older list back.
class CastBloc extends Bloc<CastEvent, CastState> {
  CastBloc(this._cast, this._errors, {DateTime Function()? clock})
    : _ids = IdSource(clock: clock),
      super(const CastState()) {
    on<CastOpened>(_onOpened);
    on<_CastChanged>(
      (event, emit) => emit(
        state.copyWith(characters: event.library.characters, packs: event.library.packs),
      ),
    );
    on<CastExported>(_onExported);
    on<CastEdit>(_onEdit, transformer: sequential());
    _changes = _cast.changes.listen((library) => add(_CastChanged(library)));
  }

  final CastRepository _cast;
  final FailureSink _errors;
  final IdSource _ids;
  late final StreamSubscription<CharacterLibrary> _changes;

  /// How many imports have been said, so the next is told from the last.
  var _imports = 0;

  Future<void> _onOpened(CastOpened event, Emitter<CastState> emit) async {
    try {
      final library = await _cast.load();
      emit(state.copyWith(characters: library.characters, packs: library.packs, loading: false));
    } catch (exception) {
      emit(state.copyWith(loading: false));
      _errors.report(exception);
    }
  }

  Future<void> _onExported(CastExported event, Emitter<CastState> emit) async {
    try {
      await _cast.exportTo(
        event.destination,
        CharacterLibrary(characters: event.characters, packs: [?event.pack]),
      );
    } catch (exception) {
      _errors.report(exception);
    }
  }

  /// Hands each edit to its own method. Every one of them reads the
  /// repository's cast, not this screen's: the canvas writes there too.
  Future<void> _onEdit(CastEdit event, Emitter<CastState> emit) => switch (event) {
    CardAdded(:final name) => _write(
      characters: [
        ..._cast.cast,
        Character(id: _ids.next(), name: name, vector: const []),
      ],
    ),
    CardRenamed(:final id, :final name) => _editCard(id, (card) => card.copyWith(name: name)),
    CardVoicedAs(:final id, :final target) => _report(() => _cast.voiceAs(id, target)),
    CardRemoved(:final id) => _removeCard(id),
    PackAdded(:final name) => _write(
      packs: [
        ..._cast.library.packs,
        CharacterPack(id: _ids.next(), name: name),
      ],
    ),
    PackRenamed(:final id, :final name) => _editPack(id, (pack) => pack.copyWith(name: name)),
    PackRemoved(:final id) => _removePack(id),
    CardPacked(:final packId, :final characterId) => _packCard(packId, characterId),
    CardUnpacked(:final packId, :final characterId) => _editPack(
      packId,
      (pack) => pack.withoutCharacter(characterId),
    ),
    CastImported(:final files) => _import(files, emit),
  };

  Future<void> _editCard(String id, Character Function(Character card) edit) => _write(
    characters: [
      for (final card in _cast.cast)
        if (card.id == id) edit(card) else card,
    ],
  );

  Future<void> _editPack(String id, CharacterPack Function(CharacterPack pack) edit) => _write(
    packs: [
      for (final pack in _cast.library.packs)
        if (pack.id == id) edit(pack) else pack,
    ],
  );

  /// Deleting a pack leaves its cards: only the grouping was the pack's.
  Future<void> _removePack(String id) => _write(
    packs: [
      for (final pack in _cast.library.packs)
        if (pack.id != id) pack,
    ],
  );

  /// A card that is gone by the time it lands is not put anywhere.
  Future<void> _packCard(String packId, String characterId) async {
    if (!_cast.cast.any((card) => card.id == characterId)) return;
    await _editPack(packId, (pack) => pack.withCharacter(characterId));
  }

  /// The card goes, with its clip -- a clip left behind costs a few
  /// kilobytes, and failing to remove it must not keep the card -- and out
  /// of every pack that held it, so no pack draws a member that is gone.
  Future<void> _removeCard(String id) async {
    try {
      await _cast.removeClip(id);
    } on Object {
      // Nothing to tell the player: the card goes either way.
    }
    await _write(
      characters: [
        for (final card in _cast.cast)
          if (card.id != id) card,
      ],
      packs: [for (final pack in _cast.library.packs) pack.withoutCharacter(id)],
    );
  }

  Future<void> _import(List<String> files, Emitter<CastState> emit) async {
    final CharacterLibrary incoming;
    try {
      incoming = await _cast.readFiles(files);
    } catch (exception) {
      _errors.report(exception);
      return;
    }
    final characters = mergeCharacters(_cast.cast, incoming.characters);
    await _write(
      characters: characters,
      packs: prunePacks(mergePacks(_cast.library.packs, incoming.packs), characters),
    );
    emit(
      state.copyWith(
        lastImport: CastImport(
          number: ++_imports,
          characters: incoming.characters.length,
          packs: incoming.packs.length,
        ),
      ),
    );
  }

  /// Writes the cards and the packs -- they go in one file, so both are
  /// written whichever changed. Nothing is emitted: the repository
  /// publishes as it writes, and this is listening.
  Future<void> _write({List<Character>? characters, List<CharacterPack>? packs}) => _report(
    () => _cast.save(
      CharacterLibrary(
        characters: characters ?? _cast.cast,
        packs: packs ?? _cast.library.packs,
      ),
    ),
  );

  Future<void> _report(Future<void> Function() work) async {
    try {
      await work();
    } catch (exception) {
      _errors.report(exception);
    }
  }

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }
}
