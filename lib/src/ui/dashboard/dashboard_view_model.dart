// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/app_repository.dart';
import '../../data/repositories/model_repository.dart';
import '../../domain/app_settings.dart';
import '../../domain/game_process.dart';
import '../../domain/model_package.dart';
import '../../domain/pipeline_state.dart';

enum DashboardSection { live, models, settings }

class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel(this._appRepository, this._modelRepository);

  final AppRepository _appRepository;
  final ModelRepository _modelRepository;
  StreamSubscription<Map<String, Object?>>? _eventSubscription;

  DashboardSection section = DashboardSection.live;
  AppSettings settings = const AppSettings();
  List<GameProcess> processes = const [];
  GameProcess? selectedProcess;
  List<ModelInstallState> models = const [];
  List<TranscriptEntry> transcript = const [];
  PipelineStatus status = PipelineStatus.idle;
  bool initializing = true;
  bool searchingPython = false;

  /// How far the pipeline is through starting, and what it is doing.
  double? startupProgress;
  String startupStage = '';

  /// The language auto-detection settled on, once whisper has reported it.
  String? detectedLanguage;
  String? error;
  String modelDirectoryPath = '';

  bool get requiredModelsInstalled =>
      models.isNotEmpty &&
      models.every((state) {
        if (settings.captureMode == CaptureMode.ocr && state.model.id == 'whisper-base') {
          return true;
        }
        return state.installed;
      });
  bool get canStart =>
      !initializing &&
      status == PipelineStatus.idle &&
      (!_requiresProcess || selectedProcess != null) &&
      requiredModelsInstalled;
  bool get _requiresProcess =>
      settings.captureMode == CaptureMode.ocr ||
      settings.audioCaptureSource == AudioCaptureSource.process;
  bool get running => status == PipelineStatus.starting || status == PipelineStatus.listening;

  Future<void> initialize() async {
    _eventSubscription = _appRepository.events.listen(_handleEvent);
    try {
      final values = await Future.wait<Object>([
        _appRepository.loadSettings(),
        _appRepository.listProcesses(),
        _modelRepository.loadStates(),
        _modelRepository.rootDirectory(),
      ]);
      settings = values[0] as AppSettings;
      processes = values[1] as List<GameProcess>;
      models = values[2] as List<ModelInstallState>;
      modelDirectoryPath = values[3] as String;
    } catch (exception) {
      error = 'Не удалось инициализировать приложение: $exception';
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  void selectSection(DashboardSection value) {
    section = value;
    notifyListeners();
  }

  void selectProcess(GameProcess? value) {
    selectedProcess = value;
    notifyListeners();
  }

  Future<void> refreshProcesses() async {
    processes = await _appRepository.listProcesses();
    final matches = processes.where(
      (process) => process.pid == selectedProcess?.pid,
    );
    selectedProcess = matches.isEmpty ? null : matches.first;
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings value) async {
    settings = value;
    notifyListeners();
    await _appRepository.saveSettings(value);
  }

  /// Finds an interpreter that can run the worker and saves it. Returns the
  /// path so the settings field can show what was picked.
  Future<String?> findPythonExecutable() async {
    searchingPython = true;
    error = null;
    notifyListeners();
    try {
      final result = await _appRepository.findPythonExecutable();
      final executable = result.executable;
      if (executable == null) {
        error = result.describeFailure();
        return null;
      }
      await updateSettings(settings.copyWith(pythonExecutable: executable));
      return executable;
    } catch (exception) {
      error = 'Не удалось найти Python: $exception';
      return null;
    } finally {
      searchingPython = false;
      notifyListeners();
    }
  }

  Future<void> installModel(ModelInstallState state) async {
    final index = models.indexOf(state);
    if (index < 0 || state.downloading) return;
    error = null;
    models[index] = state.copyWith(progress: 0, clearError: true);
    notifyListeners();
    try {
      await _modelRepository.install(
        state.model,
        proxyUrl: settings.modelProxyUrl,
        onProgress: (progress) {
          models[index] = models[index].copyWith(progress: progress);
          notifyListeners();
        },
      );
      models[index] = models[index].copyWith(
        installed: true,
        clearProgress: true,
      );
    } catch (exception) {
      models[index] = models[index].copyWith(
        clearProgress: true,
        error: '$exception',
      );
    }
    notifyListeners();
  }

  Future<void> togglePipeline() async {
    error = null;
    if (running) {
      status = PipelineStatus.stopping;
      notifyListeners();
      try {
        await _appRepository.stop();
        status = PipelineStatus.idle;
      } catch (exception) {
        status = PipelineStatus.error;
        error = '$exception';
      }
      startupProgress = null;
      startupStage = '';
      notifyListeners();
      return;
    }
    if (!canStart) return;
    status = PipelineStatus.starting;
    startupProgress = null;
    startupStage = '';
    detectedLanguage = null;
    notifyListeners();
    try {
      final directories = <String, String>{};
      for (final state in models) {
        directories[state.model.id] = await _modelRepository.directoryFor(
          state.model,
        );
      }
      await _appRepository.start(
        process: _requiresProcess ? selectedProcess : null,
        settings: settings,
        modelDirectories: directories,
      );
    } catch (exception) {
      status = PipelineStatus.error;
      error = '$exception';
      notifyListeners();
    }
  }

  Future<void> openModelDirectory() async {
    error = null;
    try {
      await _modelRepository.openRootDirectory();
    } catch (exception) {
      error = '$exception';
      notifyListeners();
    }
  }

  void _handleEvent(Map<String, Object?> event) {
    switch (event['type']) {
      case 'state':
        status = switch (event['state']) {
          'ready' || 'listening' => PipelineStatus.listening,
          'starting' => PipelineStatus.starting,
          _ => PipelineStatus.idle,
        };
        if (status != PipelineStatus.starting) {
          startupProgress = null;
          startupStage = '';
        }
      case 'transcript':
        transcript = [
          TranscriptEntry(
            original: event['original'] as String? ?? '',
            english: event['english'] as String? ?? '',
            translated: event['translated'] as String? ?? '',
            latency: Duration(
              milliseconds: event['latencyMs'] as int? ?? 0,
            ),
          ),
          ...transcript.take(49),
        ];
      case 'startup':
        startupProgress = (event['value'] as num?)?.toDouble();
        startupStage = event['stage'] as String? ?? '';
      case 'language':
        detectedLanguage = event['code'] as String?;
      case 'error':
        // A phrase failing does not stop the capture, so the pipeline keeps
        // its state and the controls stay usable. Marking the session as
        // failed here used to leave it stuck: neither startable nor stoppable.
        error = event['message'] as String? ?? 'Неизвестная ошибка';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _appRepository.dispose();
    super.dispose();
  }
}
