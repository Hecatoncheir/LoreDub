// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/app_repository.dart';
import '../../../domain/glossary.dart';
import 'shell_cubit.dart';

/// What the player has written down about their games, and whether it has
/// been read off disk yet.
class GlossaryState {
  const GlossaryState({this.glossary = Glossary.empty, this.loaded = false});

  final Glossary glossary;

  /// Told apart from an empty glossary so the screen can say "nothing here
  /// yet" rather than flash it while the file is being read.
  final bool loaded;

  GlossaryState copyWith({Glossary? glossary, bool? loaded}) =>
      GlossaryState(glossary: glossary ?? this.glossary, loaded: loaded ?? this.loaded);
}

/// The glossary screen.
///
/// Every edit is written through to the file and to a session already
/// running: the player writes an entry down because they just heard the line
/// go wrong, and mean the next one to be said their way.
class GlossaryCubit extends Cubit<GlossaryState> {
  GlossaryCubit(this._appRepository, this._errors) : super(const GlossaryState());

  final AppRepository _appRepository;
  final FailureSink _errors;

  Future<void> load() async {
    try {
      emit(GlossaryState(glossary: await _appRepository.loadGlossary(), loaded: true));
    } catch (error) {
      emit(state.copyWith(loaded: true));
      _errors.report(error);
    }
  }

  /// Writes [entry] down, replacing whatever stood for the same source.
  Future<void> write(GlossaryEntry entry) async {
    if (entry.isEmpty) return;
    await _keep(
      state.glossary.keeping(
        GlossaryEntry(
          kind: entry.kind,
          source: entry.source.trim(),
          reading: entry.reading.trim(),
        ),
      ),
    );
  }

  /// Takes an entry out. What it was standing in for goes back to being
  /// translated and transliterated the way everything else is.
  Future<void> remove(GlossaryKind kind, String source) =>
      _keep(state.glossary.without(kind, source));

  /// Writes everything down where the player asked.
  Future<void> export(String destination) async {
    try {
      await _appRepository.exportGlossary(destination, state.glossary);
    } catch (error) {
      _errors.report(error);
    }
  }

  /// Opens a pack with no entries in it. The player fills it by dragging
  /// what they have already written down into it.
  Future<GlossaryPack> addPack(String name) async {
    final pack = GlossaryPack(id: _newId(), name: name);
    await _keep(state.glossary.keepingPack(pack));
    return pack;
  }

  Future<void> renamePack(String id, String name) async {
    final pack = state.glossary.packWithId(id);
    if (pack == null) return;
    await _keep(state.glossary.keepingPack(pack.copyWith(name: name)));
  }

  /// Throws the grouping away and leaves the entries. The player wrote them
  /// down; only the grouping was ever the pack's.
  Future<void> removePack(String id) => _keep(state.glossary.withoutPack(id));

  /// Switches a pack on or off. With any pack on, the dubbing reads only
  /// what the switched-on packs hold.
  Future<void> activatePack(String id, {required bool active}) =>
      _keep(state.glossary.activating(id, active: active));

  /// Where an entry dragged onto a pack lands. [from] is the pack it was
  /// dragged out of, if it came from one rather than from a list.
  Future<void> fileInPack(GlossaryEntry entry, {required String into, String? from}) =>
      _keep(state.glossary.filing(entry, into: into, from: from));

  Future<void> takeFromPack(GlossaryEntry entry, {required String from}) =>
      _keep(state.glossary.unfiling(entry, from: from));

  /// Writes one pack out with the entries it names, so it can be read back
  /// on another machine where those entries do not exist yet.
  Future<void> exportPack(String destination, String packId) async {
    try {
      await _appRepository.exportGlossary(destination, state.glossary.onlyPack(packId));
    } catch (error) {
      _errors.report(error);
    }
  }

  /// Reads the files the player chose into what is already here. Merged by
  /// what an entry is filed under, so importing the same file twice leaves
  /// one of each rather than two, and a file that disagrees wins -- the
  /// player chose it just now.
  Future<void> import(List<String> sources) async {
    try {
      final incoming = await _appRepository.readGlossaryFiles(sources);
      var merged = state.glossary;
      for (final entry in incoming.entries) {
        merged = merged.keeping(entry);
      }
      for (final pack in incoming.packs) {
        // A pack already here keeps whether it was switched on: the file
        // brings entries and a name, and must not quietly change which
        // glossary the next line is read against.
        final here = merged.packWithId(pack.id);
        merged = merged.keepingPack(pack.copyWith(active: here?.active ?? false));
      }
      await _keep(merged);
    } catch (error) {
      _errors.report(error);
    }
  }

  /// Stages a state a widget test wants to render without reading a file.
  @visibleForTesting
  void seed(GlossaryState value) => emit(value);

  /// The same scheme the cast uses: the clock, never going backwards inside
  /// one run, in base 36.
  String _newId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    _lastId = now > _lastId ? now : _lastId + 1;
    return _lastId.toRadixString(36);
  }

  int _lastId = 0;

  Future<void> _keep(Glossary glossary) async {
    final previous = state.glossary;
    emit(state.copyWith(glossary: glossary));
    try {
      await _appRepository.saveGlossary(glossary);
    } catch (error) {
      // Put back what is actually on disk rather than leave the screen
      // showing an entry the file does not hold.
      emit(state.copyWith(glossary: previous));
      _errors.report(error);
    }
  }
}
