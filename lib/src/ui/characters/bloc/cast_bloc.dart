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

part 'cast_event.dart';
part 'cast_state.dart';

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
