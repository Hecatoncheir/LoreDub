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

  /// Stages a state a widget test wants to render without reading a file.
  @visibleForTesting
  void seed(GlossaryState value) => emit(value);

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
