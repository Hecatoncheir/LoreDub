// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/cast_repository.dart';
import '../../../data/repositories/install_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/sources_repository.dart';
import '../../../domain/compute_device.dart';
import '../../../domain/model_selection.dart';
import '../../../domain/session_coordinator.dart';
import '../../graph/canvas/pipeline_facts.dart';

sealed class PipelineFactsEvent {
  const PipelineFactsEvent();
}

/// One of the things the scheme is drawn from changed.
final class _FactsMoved extends PipelineFactsEvent {
  const _FactsMoved();
}

/// What the nodes of the scheme write on themselves, worked out in one
/// place.
///
/// The scheme is drawn from five things -- the settings, what is installed,
/// the cast, the game named and what the engine is doing -- and the panel
/// used to put them together itself, under a listener for each: a pyramid
/// of builders, every level of which knew which fields of its cubit the
/// scheme cared about. Each of the five is published now, so the facts are
/// a state of their own, made again only when one of them moves, and the
/// panel reads one thing.
class PipelineFactsBloc extends Bloc<PipelineFactsEvent, PipelineFacts> {
  PipelineFactsBloc(this._settings, this._installed, this._cast, this._sources, this._sessions)
    // Read as they stand at the start: the repositories do not replay.
    : super(_factsOf(_settings, _installed, _cast, _sources, _sessions)) {
    on<_FactsMoved>(
      (event, emit) => emit(_factsOf(_settings, _installed, _cast, _sources, _sessions)),
    );
    void moved(Object? _) => add(const _FactsMoved());
    _changes = [
      _settings.changes.listen(moved),
      // What is there and what it can run on; a download on its way is
      // none of the scheme's business, however often it is told.
      _installed.changes.map(_whatIsThere).distinct().listen(moved),
      _cast.changes.listen(moved),
      // The monitors and the list itself are none of the scheme's business.
      _sources.changes.map((sources) => sources.selected).distinct().listen(moved),
      _sessions.changes.listen(moved),
    ];
  }

  final SettingsRepository _settings;
  final InstallRepository _installed;
  final CastRepository _cast;
  final SourcesRepository _sources;
  final SessionCoordinator _sessions;
  late final List<StreamSubscription<Object?>> _changes;

  static (String, ComputeAvailability) _whatIsThere(InstalledParts parts) => (
    ([
      for (final install in parts.models)
        if (install.installed) install.model.id,
    ]..sort()).join(','),
    parts.availability,
  );

  static PipelineFacts _factsOf(
    SettingsRepository settingsRepository,
    InstallRepository installRepository,
    CastRepository cast,
    SourcesRepository sources,
    SessionCoordinator sessions,
  ) {
    final settings = settingsRepository.settings;
    final installed = installRepository.parts;
    final activity = sessions.activity;
    return PipelineFacts(
      settings: settings,
      selection: ModelSelection(models: installed.models, settings: settings),
      process: sources.sources.selected,
      characters: cast.cast,
      activeBackends: activity.backends,
      running: activity.pipelineRuns,
      paused: activity.paused,
      recordingVoice: activity.recordingVoice,
      availability: installed.availability,
    );
  }

  @override
  Future<void> close() async {
    for (final subscription in _changes) {
      await subscription.cancel();
    }
    return super.close();
  }
}
