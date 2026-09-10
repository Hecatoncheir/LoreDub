// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../../data/repositories/app_repository.dart';
import '../../data/repositories/model_repository.dart';
import '../../data/repositories/runtime_repository.dart';
import '../../domain/app_settings.dart';
import '../../domain/compute_device.dart';
import '../../domain/game_process.dart';
import '../../data/services/python_discovery.dart';
import '../../domain/failure.dart';
import '../../domain/model_package.dart';
import '../../domain/pipeline_state.dart';
import '../../domain/runtime_package.dart';

enum DashboardSection { live, models, settings }

class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel(this._appRepository, this._modelRepository, this._runtimeRepository);

  final AppRepository _appRepository;
  final ModelRepository _modelRepository;
  final RuntimeRepository _runtimeRepository;
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

  /// Interpreters the last search turned down, kept so the reason can be
  /// written out in the interface language.
  List<RejectedPython> pythonSearchRejected = const [];

  /// What went wrong, as raised. The interface writes it out.
  Object? error;
  String modelDirectoryPath = '';

  /// What this machine offers, and which GPU runtimes are downloaded.
  ComputeAvailability availability = const ComputeAvailability();
  List<RuntimeInstallState> runtimes = const [];
  String runtimeDirectoryPath = '';

  /// What a running pipeline reported it actually settled on, which can
  /// differ from the request when a driver turns out to be unusable.
  final Map<ComputeStage, ComputeBackend> _activeBackends = {};

  /// What a stage will run on: the live answer while the pipeline is up, the
  /// resolved intention otherwise.
  ComputeBackend backendFor(ComputeStage stage) =>
      _activeBackends[stage] ?? settings.backendFor(stage, availability);

  /// Whether the interface should offer this choice at all.
  bool isBackendOffered(ComputeStage stage, ComputeBackend backend) =>
      stageBackends(stage).contains(backend);

  /// Whether picking it would actually work right now.
  bool isBackendReady(ComputeStage stage, ComputeBackend backend) =>
      availability.isReady(stage, backend);

  /// The downloaded runtime this stage is using, so it can be given back.
  RuntimeInstallState? installedRuntimeFor(ComputeStage stage) {
    for (final backend in stageBackends(stage)) {
      final id = requiredRuntimeId(stage, backend);
      if (id == null || !availability.installedRuntimes.contains(id)) continue;
      for (final state in runtimes) {
        if (state.package.id == id) return state;
      }
    }
    return null;
  }

  /// The runtime a backend still needs, or null when nothing is missing.
  RuntimeInstallState? missingRuntimeFor(ComputeStage stage, ComputeBackend backend) {
    if (!availability.supportsHardware(backend)) return null;
    final id = requiredRuntimeId(stage, backend);
    if (id == null || availability.installedRuntimes.contains(id)) return null;
    for (final state in runtimes) {
      if (state.package.id == id) return state;
    }
    return null;
  }

  /// Whisper is language-independent and OCR mode does without it entirely.
  List<ModelInstallState> get recognitionModels => _modelsOfKind(ModelKind.recognition);

  List<ModelInstallState> get translationModels => _modelsOfKind(ModelKind.translation);

  List<ModelInstallState> get speechModels => _modelsOfKind(ModelKind.speech);

  List<ModelInstallState> _modelsOfKind(ModelKind kind) =>
      models.where((state) => state.model.kind == kind).toList();

  ModelInstallState? _selected(ModelKind kind) {
    for (final state in models) {
      if (state.model.kind == kind && state.model.language == settings.targetLanguage) {
        return state;
      }
    }
    return null;
  }

  /// Only the pair for the chosen language has to be present, not the whole
  /// catalogue: a player dubbing into Russian owes nothing to the French voice.
  bool get requiredModelsInstalled {
    if (models.isEmpty) return false;
    final needsWhisper = settings.captureMode != CaptureMode.ocr;
    if (needsWhisper && !(recognitionModels.firstOrNull?.installed ?? false)) return false;
    return (_selected(ModelKind.translation)?.installed ?? false) &&
        (_selected(ModelKind.speech)?.installed ?? false);
  }

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
        _runtimeRepository.rootDirectory(),
        _appRepository.probeGraphics(),
      ]);
      settings = values[0] as AppSettings;
      processes = values[1] as List<GameProcess>;
      models = values[2] as List<ModelInstallState>;
      modelDirectoryPath = values[3] as String;
      runtimeDirectoryPath = values[4] as String;
      await refreshAvailability(probe: values[5] as ComputeAvailability);
    } catch (exception) {
      error = LoreDubFailure(FailureCode.initializationFailed, detail: '$exception');
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

  /// Rereads what the machine offers. The hardware half is asked for only
  /// when it is not already known: adapters do not appear mid-session, while
  /// a runtime download finishing is exactly what changes here.
  Future<void> refreshAvailability({ComputeAvailability? probe}) async {
    final hardware = probe ?? availability;
    final installed = await _runtimeRepository.installedIds();
    availability = hardware.copyWith(installedRuntimes: installed);
    runtimes = [
      for (final package in _runtimeRepository.catalog)
        RuntimeInstallState(
          package: package,
          installed: installed.contains(package.id),
        ),
    ];
    notifyListeners();
  }

  /// Applies one of the three presets, dropping any per-stage pins so what
  /// the interface shows is what the preset decided.
  Future<void> selectComputeDevice(ComputeDevice device) =>
      updateSettings(settings.withComputeDevice(device));

  /// Pins a single stage, leaving the rest of the pipeline alone.
  Future<void> selectStageBackend(ComputeStage stage, ComputeBackend backend) =>
      updateSettings(settings.withBackend(stage, backend));

  Future<void> installRuntime(RuntimeInstallState state) async {
    final index = runtimes.indexOf(state);
    if (index < 0 || state.installing) return;
    error = null;
    runtimes[index] = state.copyWith(progress: 0, clearError: true);
    notifyListeners();
    try {
      await _runtimeRepository.install(
        state.package,
        proxyUrl: settings.modelProxyUrl,
        pythonExecutable: settings.pythonExecutable,
        onProgress: (progress) {
          runtimes[index] = runtimes[index].copyWith(progress: progress);
          notifyListeners();
        },
      );
      runtimes[index] = runtimes[index].copyWith(installed: true, clearProgress: true);
      // The new runtime changes which backends can be picked.
      await refreshAvailability();
    } catch (exception) {
      runtimes[index] = runtimes[index].copyWith(clearProgress: true, error: exception);
    }
    notifyListeners();
  }

  Future<void> removeRuntime(RuntimeInstallState state) async {
    error = null;
    try {
      await _runtimeRepository.remove(state.package);
      await refreshAvailability();
    } catch (exception) {
      error = exception;
      notifyListeners();
    }
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
    pythonSearchRejected = const [];
    notifyListeners();
    try {
      final result = await _appRepository.findPythonExecutable();
      final executable = result.executable;
      if (executable == null) {
        error = result.failure;
        pythonSearchRejected = result.rejected;
        return null;
      }
      await updateSettings(settings.copyWith(pythonExecutable: executable));
      return executable;
    } catch (exception) {
      error = LoreDubFailure(FailureCode.pythonSearchFailed, detail: '$exception');
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
      models[index] = models[index].copyWith(clearProgress: true, error: exception);
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
        error = exception;
      }
      startupProgress = null;
      startupStage = '';
      // The detection belonged to the session that just ended.
      detectedLanguage = null;
      // The devices belonged to that session too.
      _activeBackends.clear();
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
      final translation = _selected(ModelKind.translation)!.model;
      final speech = _selected(ModelKind.speech)!.model;
      final speechDirectory = await _modelRepository.directoryFor(speech);
      await _appRepository.start(
        process: _requiresProcess ? selectedProcess : null,
        settings: settings,
        modelDirectories: {
          'whisper': await _modelRepository.directoryFor(recognitionModels.first.model),
          'translation': await _modelRepository.directoryFor(translation),
          'speech': path.join(speechDirectory, speech.primaryFileName),
        },
        speaker: speech.speaker ?? '',
        recognitionBackend: settings.backendFor(ComputeStage.recognition, availability),
        translationBackend: settings.backendFor(ComputeStage.translation, availability),
        runtimeDirectory: runtimeDirectoryPath,
      );
    } catch (exception) {
      status = PipelineStatus.error;
      error = exception;
      notifyListeners();
    }
  }

  /// Choosing the language picks both the translator and the voice: text in
  /// one language read by a voice for another would be gibberish.
  Future<void> selectTargetLanguage(String language) =>
      updateSettings(settings.copyWith(targetLanguage: language));

  /// Whether both halves of a language's pair are on disk.
  bool isLanguageReady(String language) {
    var translation = false;
    var speech = false;
    for (final state in models) {
      if (state.model.language != language || !state.installed) continue;
      translation |= state.model.kind == ModelKind.translation;
      speech |= state.model.kind == ModelKind.speech;
    }
    return translation && speech;
  }

  Future<void> openModelDirectory() async {
    error = null;
    try {
      await _modelRepository.openRootDirectory();
    } catch (exception) {
      error = exception;
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
      case 'backend':
        final stage = ComputeStage.values.where((value) => value.name == event['stage']);
        final backend = ComputeBackend.values.where((value) => value.name == event['backend']);
        if (stage.isNotEmpty && backend.isNotEmpty) {
          _activeBackends[stage.first] = backend.first;
        }
      case 'error':
        // A phrase failing does not stop the capture, so the pipeline keeps
        // its state and the controls stay usable. Marking the session as
        // failed here used to leave it stuck: neither startable nor stoppable.
        error = event['failure'];
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
