// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/session_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../domain/python_search.dart';
import '../../../domain/app_settings.dart';
import '../../../domain/compute_device.dart';
import '../../../domain/engine_event.dart';
import '../../../domain/pipeline_state.dart';
import '../../../domain/failure.dart';
import 'failure_cubit.dart';
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

sealed class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => const [];
}

/// The screen is up: the settings are read once whoever asks first, and the
/// kept voices are counted.
final class SettingsOpened extends SettingsEvent {
  const SettingsOpened();
}

/// The player set [settings] as a whole: what a field, a switch or a slider
/// writes, made from [SettingsBloc.settings] as they stand.
final class SettingsChanged extends SettingsEvent {
  const SettingsChanged(this.settings);

  final AppSettings settings;

  @override
  List<Object?> get props => [settings];
}

/// Choosing the language picks both the translator and the voice: text in
/// one language read by a voice for another would be gibberish.
final class TargetLanguageChosen extends SettingsEvent {
  const TargetLanguageChosen(this.language);

  final String language;

  @override
  List<Object?> get props => [language];
}

final class RecognitionModelChosen extends SettingsEvent {
  const RecognitionModelChosen(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// One of the three presets, dropping any per-stage pins so what the
/// interface shows is what the preset decided.
final class ComputeDeviceChosen extends SettingsEvent {
  const ComputeDeviceChosen(this.device);

  final ComputeDevice device;

  @override
  List<Object?> get props => [device];
}

/// Pins a single stage, leaving the rest of the pipeline alone.
final class StageBackendPinned extends SettingsEvent {
  const StageBackendPinned(this.stage, this.backend);

  final ComputeStage stage;
  final ComputeBackend backend;

  @override
  List<Object?> get props => [stage, backend];
}

/// Finds an interpreter that can run the worker and keeps it.
final class PythonSearched extends SettingsEvent {
  const PythonSearched();
}

/// Forgets every kept voice of every game.
final class VoiceBankCleared extends SettingsEvent {
  const VoiceBankCleared();
}

final class _SettingsMoved extends SettingsEvent {
  const _SettingsMoved(this.settings);

  final AppSettings settings;
}

final class _BankMayHaveGrown extends SettingsEvent {
  const _BankMayHaveGrown();
}

/// Everything the player configured, and the two things the settings
/// screen does beside writing them: finding an interpreter, and counting
/// and clearing the kept voices.
///
/// The settings are `SettingsRepository`'s, which every screen reads; this
/// writes there and follows it, so the pipeline moving the subtitle frame
/// or flipping the overlay does not have to know a screen shows it. The
/// intentions that are made of the current settings -- a language, a
/// device, a pinned stage -- are events of their own and are made of the
/// repository's settings as they stand when answered, rather than of a
/// copy the widget held.
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc(this._session, this._settings, this._errors, this._voiceBank, this._system)
    : super(SettingsState(settings: _settings.settings)) {
    on<SettingsOpened>(_onOpened);
    on<_SettingsMoved>((event, emit) => emit(state.copyWith(settings: event.settings)));
    on<SettingsChanged>((event, emit) => _settings.save(event.settings));
    on<TargetLanguageChosen>(
      (event, emit) => _settings.save(settings.copyWith(targetLanguage: event.language)),
    );
    on<RecognitionModelChosen>(
      (event, emit) => _settings.save(settings.copyWith(whisperModel: event.id)),
    );
    on<ComputeDeviceChosen>(
      (event, emit) => _settings.save(settings.withComputeDevice(event.device)),
    );
    on<StageBackendPinned>(
      (event, emit) => _settings.save(settings.withBackend(event.stage, event.backend)),
    );
    on<PythonSearched>(_onPythonSearched);
    on<VoiceBankCleared>(_onBankCleared);
    on<_BankMayHaveGrown>((event, emit) => _countBank(emit));
    _written = _settings.changes.listen((value) => add(_SettingsMoved(value)));
    // The bank grows while a session runs, and its last voices are written
    // as that session comes to rest. The count stands beside a switch here,
    // so it is this bloc's to keep and nobody else's to refresh.
    _engine = _session.events.listen((event) {
      if (event is VoiceBankGrew ||
          (event is SessionStateChanged && event.status == PipelineStatus.idle)) {
        add(const _BankMayHaveGrown());
      }
    });
  }

  /// Heard for the voices the running session adds to the bank.
  final SessionRepository _session;
  final VoiceBankRepository _voiceBank;
  final SystemRepository _system;
  final SettingsRepository _settings;
  final FailureSink _errors;
  late final StreamSubscription<AppSettings> _written;
  late final StreamSubscription<EngineEvent> _engine;

  /// The settings as they stand, which is what a widget writing one of them
  /// builds the whole from: the repository's, never a copy an event behind.
  AppSettings get settings => _settings.settings;

  Future<void> _onOpened(SettingsOpened event, Emitter<SettingsState> emit) async {
    // What was read is shown as it is read: the repository's echo of the
    // same value comes an event later and changes nothing.
    emit(state.copyWith(settings: await _settings.load()));
    await _countBank(emit);
  }

  /// Recounts the kept voices. The count is a courtesy next to a switch, so
  /// a bank that cannot be read shows as whatever was counted last.
  Future<void> _countBank(Emitter<SettingsState> emit) async {
    try {
      emit(state.copyWith(voiceBankSize: await _voiceBank.size()));
    } catch (exception) {
      debugPrint('voice bank not counted: $exception');
    }
  }

  Future<void> _onBankCleared(VoiceBankCleared event, Emitter<SettingsState> emit) async {
    try {
      await _voiceBank.clear();
    } catch (exception) {
      _errors.report(exception);
    }
    await _countBank(emit);
  }

  /// One search at a time: a second press while one runs is passed over
  /// rather than started beside it. What it finds is written to the
  /// settings, and the field shows it from there.
  ///
  /// Not `droppable()`, which says the same thing: cancelling its
  /// subscription as the bloc closes never completes inside a widget
  /// test's zone, and every test that pumped this screen hung in its
  /// teardown -- the same trap an `async*` generator was.
  Future<void> _onPythonSearched(PythonSearched event, Emitter<SettingsState> emit) async {
    if (state.searchingPython) return;
    emit(state.copyWith(searchingPython: true, rejectedPython: const []));
    _errors.report(null);
    try {
      final result = await _system.findPythonExecutable();
      final executable = result.executable;
      if (executable == null) {
        _errors.report(result.failure);
        emit(state.copyWith(rejectedPython: result.rejected));
        return;
      }
      await _settings.save(settings.copyWith(pythonExecutable: executable));
    } catch (exception) {
      _errors.report(LoreDubFailure(FailureCode.pythonSearchFailed, detail: '$exception'));
    } finally {
      emit(state.copyWith(searchingPython: false));
    }
  }

  @override
  Future<void> close() async {
    await _written.cancel();
    await _engine.cancel();
    return super.close();
  }
}
