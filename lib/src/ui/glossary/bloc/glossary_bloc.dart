// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/glossary_repository.dart';
import '../../../domain/glossary.dart';
import '../../../domain/id_source.dart';
import '../../shell/bloc/failure_cubit.dart';

/// What the files of one import held, numbered so that two imports of the
/// same size are still two things to say.
class GlossaryImport extends Equatable {
  const GlossaryImport({required this.number, required this.entries, required this.packs});

  final int number;
  final int entries;
  final int packs;

  @override
  List<Object?> get props => [number, entries, packs];
}

/// What the player has written down about their games, and whether it has
/// been read off disk yet.
class GlossaryState extends Equatable {
  const GlossaryState({this.glossary = Glossary.empty, this.loaded = false, this.lastImport});

  final Glossary glossary;

  /// Told apart from an empty glossary so the screen can say "nothing here
  /// yet" rather than flash it while the file is being read.
  final bool loaded;

  /// What the last import read, which the screen says once. Null until the
  /// first, and left as it was by one that failed -- that is reported.
  final GlossaryImport? lastImport;

  GlossaryState copyWith({Glossary? glossary, bool? loaded, GlossaryImport? lastImport}) =>
      GlossaryState(
        glossary: glossary ?? this.glossary,
        loaded: loaded ?? this.loaded,
        lastImport: lastImport ?? this.lastImport,
      );

  @override
  List<Object?> get props => [glossary, loaded, lastImport];
}

sealed class GlossaryEvent extends Equatable {
  const GlossaryEvent();

  @override
  List<Object?> get props => const [];
}

/// The screen is up: what is written down is read, with the built-in packs
/// laid over it the first time.
final class GlossaryOpened extends GlossaryEvent {
  const GlossaryOpened();
}

/// Writes the whole glossary where the player asked.
final class GlossaryExported extends GlossaryEvent {
  const GlossaryExported(this.destination);

  final String destination;

  @override
  List<Object?> get props => [destination];
}

/// Writes one pack out with the entries it names, so it can be read back on
/// another machine where those entries do not exist yet.
final class GlossaryPackExported extends GlossaryEvent {
  const GlossaryPackExported(this.destination, this.packId);

  final String destination;
  final String packId;

  @override
  List<Object?> get props => [destination, packId];
}

/// A change to what is written down.
///
/// One kind for all of them, answered one at a time: each is made from the
/// glossary the one before it left, and the file is written in the order
/// they were asked for. Answered side by side, a drag landing while a name
/// was still being saved could be built from the glossary before it.
sealed class GlossaryEdit extends GlossaryEvent {
  const GlossaryEdit();
}

/// Writes [entry] down, replacing whatever stood for the same source.
final class GlossaryEntryWritten extends GlossaryEdit {
  const GlossaryEntryWritten(this.entry);

  final GlossaryEntry entry;

  @override
  List<Object?> get props => [entry.kind, entry.source, entry.reading, entry.silent];
}

/// Takes an entry out. What it was standing in for goes back to being
/// translated and transliterated the way everything else is.
final class GlossaryEntryRemoved extends GlossaryEdit {
  const GlossaryEntryRemoved(this.kind, this.source);

  final GlossaryKind kind;
  final String source;

  @override
  List<Object?> get props => [kind, source];
}

/// Opens a pack with no entries in it, switched off. The player fills it by
/// dragging what they have already written down into it.
final class GlossaryPackAdded extends GlossaryEdit {
  const GlossaryPackAdded(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}

final class GlossaryPackRenamed extends GlossaryEdit {
  const GlossaryPackRenamed(this.id, this.name);

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

/// Throws the grouping away and leaves the entries. The player wrote them
/// down; only the grouping was ever the pack's.
final class GlossaryPackRemoved extends GlossaryEdit {
  const GlossaryPackRemoved(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// Switches a pack on or off. With any pack on, the dubbing reads only what
/// the switched-on packs hold.
final class GlossaryPackSwitched extends GlossaryEdit {
  const GlossaryPackSwitched(this.id, {required this.active});

  final String id;
  final bool active;

  @override
  List<Object?> get props => [id, active];
}

/// Where an entry dragged onto a pack lands. [from] is the pack it was
/// dragged out of, if it came from one rather than from a list.
final class GlossaryEntryFiled extends GlossaryEdit {
  const GlossaryEntryFiled(this.entry, {required this.into, this.from});

  final GlossaryEntry entry;
  final String into;
  final String? from;

  @override
  List<Object?> get props => [entry.packKey, into, from];
}

final class GlossaryEntryUnfiled extends GlossaryEdit {
  const GlossaryEntryUnfiled(this.entry, {required this.from});

  final GlossaryEntry entry;
  final String from;

  @override
  List<Object?> get props => [entry.packKey, from];
}

/// Reads the files the player chose into what is already here.
final class GlossaryFilesImported extends GlossaryEdit {
  const GlossaryFilesImported(this.sources);

  final List<String> sources;

  @override
  List<Object?> get props => [sources];
}

/// The glossary screen.
///
/// Every edit is written through to the file and to a session already
/// running: the player writes an entry down because they just heard the line
/// go wrong, and mean the next one to be said their way.
class GlossaryBloc extends Bloc<GlossaryEvent, GlossaryState> {
  GlossaryBloc(this._glossary, this._errors, {DateTime Function()? clock})
    : _ids = IdSource(clock: clock),
      super(const GlossaryState()) {
    on<GlossaryOpened>(_onOpened);
    on<GlossaryExported>(
      (event, emit) => _export(event.destination, state.glossary),
    );
    on<GlossaryPackExported>(
      (event, emit) => _export(event.destination, state.glossary.onlyPack(event.packId)),
    );
    on<GlossaryEdit>(_onEdit, transformer: sequential());
  }

  final GlossaryRepository _glossary;
  final FailureSink _errors;
  final IdSource _ids;

  /// How many imports have been said, so the next is told from the last.
  var _imports = 0;

  Future<void> _onOpened(GlossaryOpened event, Emitter<GlossaryState> emit) async {
    try {
      emit(state.copyWith(glossary: await _glossary.load(), loaded: true));
    } catch (error) {
      emit(state.copyWith(loaded: true));
      _errors.report(error);
    }
  }

  Future<void> _export(String destination, Glossary glossary) async {
    try {
      await _glossary.exportTo(destination, glossary);
    } catch (error) {
      _errors.report(error);
    }
  }

  Future<void> _onEdit(GlossaryEdit event, Emitter<GlossaryState> emit) async {
    final glossary = state.glossary;
    final edited = switch (event) {
      GlossaryEntryWritten(:final entry) => _written(glossary, entry),
      GlossaryEntryRemoved(:final kind, :final source) => glossary.without(kind, source),
      GlossaryPackAdded(:final name) => glossary.keepingPack(
        GlossaryPack(id: _ids.next(), name: name),
      ),
      GlossaryPackRenamed(:final id, :final name) => switch (glossary.packWithId(id)) {
        final pack? => glossary.keepingPack(pack.copyWith(name: name)),
        null => null,
      },
      GlossaryPackRemoved(:final id) => glossary.withoutPack(id),
      GlossaryPackSwitched(:final id, :final active) => glossary.activating(id, active: active),
      GlossaryEntryFiled(:final entry, :final into, :final from) => glossary.filing(
        entry,
        into: into,
        from: from,
      ),
      GlossaryEntryUnfiled(:final entry, :final from) => glossary.unfiling(entry, from: from),
      GlossaryFilesImported(:final sources) => await _imported(sources, emit),
    };
    if (edited != null) await _keep(edited, emit);
  }

  /// [entry] kept, trimmed, in place of whatever stood for the same source;
  /// null for an entry with nothing in it.
  static Glossary? _written(Glossary glossary, GlossaryEntry entry) {
    if (entry.isEmpty) return null;
    return glossary.keeping(
      GlossaryEntry(
        kind: entry.kind,
        source: entry.source.trim(),
        reading: entry.reading.trim(),
        silent: entry.silent,
      ),
    );
  }

  /// What is here with the files read into it, merged by what an entry is
  /// filed under: importing the same file twice leaves one of each rather
  /// than two, and a file that disagrees wins -- the player chose it just
  /// now. Says how much the files held; null when they could not be read,
  /// which is reported instead.
  Future<Glossary?> _imported(List<String> sources, Emitter<GlossaryState> emit) async {
    final Glossary incoming;
    try {
      incoming = await _glossary.readFiles(sources);
    } catch (error) {
      _errors.report(error);
      return null;
    }
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
    emit(
      state.copyWith(
        lastImport: GlossaryImport(
          number: ++_imports,
          entries: incoming.entries.length,
          packs: incoming.packs.length,
        ),
      ),
    );
    return merged;
  }

  /// Shows [glossary] at once and writes it behind that, putting back what
  /// is on disk if the write fails rather than leave the screen showing an
  /// entry the file does not hold.
  Future<void> _keep(Glossary glossary, Emitter<GlossaryState> emit) async {
    final previous = state.glossary;
    emit(state.copyWith(glossary: glossary));
    try {
      await _glossary.save(glossary);
    } catch (error) {
      emit(state.copyWith(glossary: previous));
      _errors.report(error);
    }
  }
}
