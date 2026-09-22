// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/sources_repository.dart';
import '../../../domain/capture_sources.dart';
import '../../../domain/game_process.dart';
import 'failure_cubit.dart';

sealed class SourcesEvent extends Equatable {
  const SourcesEvent();

  @override
  List<Object?> get props => const [];
}

/// The player asked for the processes and the monitors to be listed again.
final class SourcesRefreshed extends SourcesEvent {
  const SourcesRefreshed();
}

/// The player named a game, or took the name back.
final class SourcePicked extends SourcesEvent {
  const SourcePicked(this.process);

  final GameProcess? process;

  @override
  List<Object?> get props => [process];
}

/// What the repository published, whoever changed it.
final class _SourcesChanged extends SourcesEvent {
  const _SourcesChanged(this.sources);

  final CaptureSources sources;

  @override
  List<Object?> get props => [sources];
}

/// The game picker's side of [SourcesRepository], for the widgets.
///
/// It writes nothing into its own state: a pick goes to the repository and
/// comes back through its stream like any other change, so a game named in
/// the node panel and one named on Live arrive the same way.
class SourcesBloc extends Bloc<SourcesEvent, CaptureSources> {
  SourcesBloc(this._sources, this._errors) : super(_sources.sources) {
    on<SourcesRefreshed>(_onRefreshed);
    on<SourcePicked>((event, emit) => _sources.select(event.process));
    on<_SourcesChanged>((event, emit) => emit(event.sources));
    _changes = _sources.changes.listen((sources) => add(_SourcesChanged(sources)));
  }

  final SourcesRepository _sources;
  final FailureSink _errors;
  late final StreamSubscription<CaptureSources> _changes;

  Future<void> _onRefreshed(SourcesRefreshed event, Emitter<CaptureSources> emit) async {
    try {
      await _sources.load();
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
