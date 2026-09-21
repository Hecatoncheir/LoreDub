// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/session_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/python_discovery.dart';
import '../../../domain/app_settings.dart';
import '../../../domain/compute_device.dart';
import '../../../domain/engine_event.dart';
import '../../../domain/pipeline_state.dart';
import '../../../domain/failure.dart';
import 'shell_cubit.dart';
import '../../../data/repositories/voice_bank_repository.dart';
import '../../../data/repositories/system_repository.dart';

/// Everything the user configured, plus the interpreter search that writes
/// into it.
class SettingsState extends Equatable {
  const SettingsState({
    this.settings = const AppSettings(),
    this.searchingPython = false,
    this.rejectedPython = const [],
    this.voiceBankSize = 0,
  });

  final AppSettings settings;
  final bool searchingPython;

  /// Interpreters the last search turned down, kept so the reason can be
  /// written out in the interface language.
  final List<RejectedPython> rejectedPython;

  /// How many voices the original voice has kept, across all games.
  final int voiceBankSize;

  SettingsState copyWith({
    AppSettings? settings,
    bool? searchingPython,
    List<RejectedPython>? rejectedPython,
    int? voiceBankSize,
  }) => SettingsState(
    settings: settings ?? this.settings,
    searchingPython: searchingPython ?? this.searchingPython,
    rejectedPython: rejectedPython ?? this.rejectedPython,
    voiceBankSize: voiceBankSize ?? this.voiceBankSize,
  );

  @override
  List<Object?> get props => [
    settings,
    searchingPython,
    rejectedPython,
    voiceBankSize,
  ];
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._session, this._settings, this._errors, this._voiceBank, this._system)
    : super(SettingsState(settings: _settings.settings)) {
    // Whoever writes a setting writes it to the repository, which is where
    // this reads it back from: the pipeline moving the subtitle frame or
    // flipping the overlay does not have to know there is a screen showing
    // what it changed.
    _written = _settings.changes.listen(
      (value) => emit(state.copyWith(settings: value)),
    );
    // The bank grows while a session runs, and its last voices are written
    // as that session comes to rest. The count stands beside a switch here,
    // so it is this cubit's to keep and nobody else's to refresh.
    _engine = _session.events.listen((event) {
      if (event is VoiceBankGrew ||
          (event is SessionStateChanged && event.status == PipelineStatus.idle)) {
        unawaited(refreshVoiceBank());
      }
    });
  }

  /// Heard for the voices the running session adds to the bank.
  final SessionRepository _session;
  final VoiceBankRepository _voiceBank;
  final SystemRepository _system;
  final SettingsRepository _settings;
  final FailureSink _errors;
  StreamSubscription<AppSettings>? _written;
  StreamSubscription<EngineEvent>? _engine;

  AppSettings get settings => state.settings;

  Future<void> load() async {
    await _settings.load();
    await refreshVoiceBank();
  }

  /// Recounts the kept voices. The count is a courtesy next to a switch, so
  /// a bank that cannot be read shows as whatever was counted last.
  Future<void> refreshVoiceBank() async {
    try {
      final size = await _voiceBank.size();
      if (!isClosed) emit(state.copyWith(voiceBankSize: size));
    } catch (exception) {
      debugPrint('voice bank not counted: $exception');
    }
  }

  /// Forgets every kept voice of every game.
  Future<void> clearVoiceBank() async {
    try {
      await _voiceBank.clear();
    } catch (exception) {
      _errors.report(exception);
    }
    await refreshVoiceBank();
  }

  /// Nothing is emitted here. The repository publishes as it writes and
  /// this cubit is listening, so the change is on screen before this
  /// returns; emitting as well made the screen a second writer of one
  /// value, and its own echo arriving afterwards could put the older one
  /// back.
  Future<void> update(AppSettings value) => _settings.save(value);

  /// Choosing the language picks both the translator and the voice: text in
  /// one language read by a voice for another would be gibberish.
  Future<void> selectTargetLanguage(String language) =>
      update(settings.copyWith(targetLanguage: language));

  Future<void> selectRecognitionModel(String id) => update(settings.copyWith(whisperModel: id));

  /// Applies one of the three presets, dropping any per-stage pins so what
  /// the interface shows is what the preset decided.
  Future<void> selectComputeDevice(ComputeDevice device) =>
      update(settings.withComputeDevice(device));

  /// Pins a single stage, leaving the rest of the pipeline alone.
  Future<void> selectStageBackend(ComputeStage stage, ComputeBackend backend) =>
      update(settings.withBackend(stage, backend));

  /// Finds an interpreter that can run the worker and saves it. Returns the
  /// path so the settings field can show what was picked.
  Future<String?> findPythonExecutable() async {
    emit(state.copyWith(searchingPython: true, rejectedPython: const []));
    _errors.report(null);
    try {
      final result = await _system.findPythonExecutable();
      final executable = result.executable;
      if (executable == null) {
        _errors.report(result.failure);
        emit(state.copyWith(rejectedPython: result.rejected));
        return null;
      }
      await update(settings.copyWith(pythonExecutable: executable));
      return executable;
    } catch (exception) {
      _errors.report(LoreDubFailure(FailureCode.pythonSearchFailed, detail: '$exception'));
      return null;
    } finally {
      emit(state.copyWith(searchingPython: false));
    }
  }

  /// Stages a state a widget test wants to render without touching disk.
  ///
  /// The settings go to the repository as well, and this cubit's own state
  /// at once rather than through the stream: everything that reads them
  /// reads them there, and a test that staged only this cubit drew a
  /// screen from one set of settings while the pipeline behind it ran on
  /// another.
  @visibleForTesting
  void seed(SettingsState value) {
    _settings.seed(value.settings);
    emit(value);
  }

  @override
  Future<void> close() async {
    await _written?.cancel();
    await _engine?.cancel();
    return super.close();
  }
}
