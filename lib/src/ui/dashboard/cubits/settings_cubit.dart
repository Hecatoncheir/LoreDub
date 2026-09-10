// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/app_repository.dart';
import '../../../data/services/python_discovery.dart';
import '../../../domain/app_settings.dart';
import '../../../domain/compute_device.dart';
import '../../../domain/failure.dart';
import 'shell_cubit.dart';

/// Everything the user configured, plus the interpreter search that writes
/// into it.
class SettingsState {
  const SettingsState({
    this.settings = const AppSettings(),
    this.searchingPython = false,
    this.rejectedPython = const [],
  });

  final AppSettings settings;
  final bool searchingPython;

  /// Interpreters the last search turned down, kept so the reason can be
  /// written out in the interface language.
  final List<RejectedPython> rejectedPython;

  SettingsState copyWith({
    AppSettings? settings,
    bool? searchingPython,
    List<RejectedPython>? rejectedPython,
  }) => SettingsState(
    settings: settings ?? this.settings,
    searchingPython: searchingPython ?? this.searchingPython,
    rejectedPython: rejectedPython ?? this.rejectedPython,
  );
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._appRepository, this._errors) : super(const SettingsState());

  final AppRepository _appRepository;
  final FailureSink _errors;

  AppSettings get settings => state.settings;

  Future<void> load() async {
    emit(state.copyWith(settings: await _appRepository.loadSettings()));
  }

  Future<void> update(AppSettings value) async {
    emit(state.copyWith(settings: value));
    await _appRepository.saveSettings(value);
  }

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
      final result = await _appRepository.findPythonExecutable();
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
  @visibleForTesting
  void seed(SettingsState value) => emit(value);
}
