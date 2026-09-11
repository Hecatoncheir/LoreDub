// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as path;

import '../../../data/repositories/app_repository.dart';
import '../../../data/repositories/model_repository.dart';
import '../../../domain/app_settings.dart';
import '../../../domain/compute_device.dart';
import '../../../domain/game_process.dart';
import '../../../domain/model_package.dart';
import '../../../domain/model_selection.dart';
import '../../../domain/pipeline_state.dart';
import 'downloads_cubit.dart';
import 'settings_cubit.dart';
import 'shell_cubit.dart';

/// The running session: what it is doing, what it heard, and what it chose
/// to run on.
class LivePipelineState {
  const LivePipelineState({
    this.status = PipelineStatus.idle,
    this.transcript = const [],
    this.processes = const [],
    this.selectedProcess,
    this.startupProgress,
    this.startupStage = '',
    this.detectedLanguage,
    this.spokenVoice,
    this.activeBackends = const {},
    this.session = PipelineSession.live,
    this.snapshots = const [],
    this.snapshotReading = false,
    this.snapshotMissed = false,
  });

  final PipelineStatus status;
  final List<TranscriptEntry> transcript;
  final List<GameProcess> processes;
  final GameProcess? selectedProcess;

  /// How far the pipeline is through starting, and what it is doing.
  final double? startupProgress;
  final String startupStage;

  /// The language auto-detection settled on, once whisper has reported it.
  final String? detectedLanguage;

  /// The voice the running session last read a line in, once it has.
  final String? spokenVoice;

  /// What a running pipeline reported it actually settled on, which can
  /// differ from the request when a driver turns out to be unusable.
  final Map<ComputeStage, ComputeBackend> activeBackends;

  /// Which session [status] describes. Meaningless while idle.
  final PipelineSession session;

  /// What the player selected and had translated, newest first. Kept apart
  /// from [transcript], which follows the running capture.
  final List<TranscriptEntry> snapshots;

  /// Set from the moment a selection is let go until its translation, or
  /// the news that it held no text, arrives.
  final bool snapshotReading;

  /// Whether the last selection held no text Windows could read.
  final bool snapshotMissed;

  /// A paused session is still a session: its settings stay locked and its
  /// models loaded.
  bool get running =>
      status == PipelineStatus.starting ||
      status == PipelineStatus.listening ||
      status == PipelineStatus.paused;

  /// Live dubbing is up, starting or resting.
  bool get liveRunning => running && session == PipelineSession.live;

  /// The snapshot session is up and waiting for a selection.
  bool get snapshotRunning =>
      session == PipelineSession.snapshot && status == PipelineStatus.listening;

  /// The reported devices as a value that can be compared, so the compute
  /// card can be held still through everything else the session reports.
  String get backendSignature =>
      [for (final entry in activeBackends.entries) '${entry.key.name}:${entry.value.name}'].join();

  /// What a stage will run on: the live answer while the pipeline is up, the
  /// resolved intention otherwise.
  ComputeBackend backendFor(
    ComputeStage stage,
    AppSettings settings,
    ComputeAvailability availability,
  ) => activeBackends[stage] ?? settings.backendFor(stage, availability);

  /// A running snapshot session does not stand in the way: starting live
  /// dubbing takes the worker over from it.
  bool canStart(ModelSelection selection, {required bool initializing}) =>
      !initializing &&
      (status == PipelineStatus.idle || snapshotRunning) &&
      (!selection.requiresProcess || selectedProcess != null) &&
      selection.requiredModelsInstalled;

  /// The snapshot session needs its pair of models and a key to select with.
  bool canStartSnapshot(ModelSelection selection, {required bool initializing}) =>
      !initializing &&
      status == PipelineStatus.idle &&
      selection.snapshotModelsInstalled &&
      selection.settings.snapshotHotkey != null;

  LivePipelineState copyWith({
    PipelineStatus? status,
    List<TranscriptEntry>? transcript,
    List<GameProcess>? processes,
    GameProcess? selectedProcess,
    bool clearSelectedProcess = false,
    double? startupProgress,
    bool clearStartupProgress = false,
    String? startupStage,
    String? detectedLanguage,
    bool clearDetectedLanguage = false,
    String? spokenVoice,
    bool clearSpokenVoice = false,
    Map<ComputeStage, ComputeBackend>? activeBackends,
    PipelineSession? session,
    List<TranscriptEntry>? snapshots,
    bool? snapshotReading,
    bool? snapshotMissed,
  }) => LivePipelineState(
    status: status ?? this.status,
    transcript: transcript ?? this.transcript,
    processes: processes ?? this.processes,
    selectedProcess: clearSelectedProcess ? null : selectedProcess ?? this.selectedProcess,
    startupProgress: clearStartupProgress ? null : startupProgress ?? this.startupProgress,
    startupStage: startupStage ?? this.startupStage,
    detectedLanguage: clearDetectedLanguage ? null : detectedLanguage ?? this.detectedLanguage,
    spokenVoice: clearSpokenVoice ? null : spokenVoice ?? this.spokenVoice,
    activeBackends: activeBackends ?? this.activeBackends,
    session: session ?? this.session,
    snapshots: snapshots ?? this.snapshots,
    snapshotReading: snapshotReading ?? this.snapshotReading,
    snapshotMissed: snapshotMissed ?? this.snapshotMissed,
  );
}

class PipelineCubit extends Cubit<LivePipelineState> {
  PipelineCubit(
    this._appRepository,
    this._modelRepository,
    this._settings,
    this._downloads,
    this._errors, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const LivePipelineState());

  /// How long after a start a second press is taken for the rest of a
  /// double-click. Windows counts clicks as double within 500 ms by default.
  static const doubleClickGrace = Duration(milliseconds: 800);

  final AppRepository _appRepository;
  final ModelRepository _modelRepository;
  final SettingsCubit _settings;
  final DownloadsCubit _downloads;
  final FailureSink _errors;
  final DateTime Function() _clock;
  StreamSubscription<Map<String, Object?>>? _events;

  /// When the last start was asked for. The button that starts the pipeline
  /// also cancels a start in progress, so without this a double-click would
  /// start and cancel at once and leave "Stopped" with nothing to explain it.
  DateTime? _startRequestedAt;

  ModelSelection get _selection =>
      ModelSelection(models: _downloads.state.models, settings: _settings.settings);

  void listen() => _events = _appRepository.events.listen(_handleEvent);

  Future<void> loadProcesses() async {
    final processes = await _appRepository.listProcesses();
    if (isClosed) return;
    emit(state.copyWith(processes: processes));
  }

  void selectProcess(GameProcess? value) =>
      emit(state.copyWith(selectedProcess: value, clearSelectedProcess: value == null));

  Future<void> refreshProcesses() async {
    final processes = await _appRepository.listProcesses();
    if (isClosed) return;
    final matches = processes.where((process) => process.pid == state.selectedProcess?.pid);
    emit(
      state.copyWith(
        processes: processes,
        selectedProcess: matches.firstOrNull,
        clearSelectedProcess: matches.isEmpty,
      ),
    );
  }

  Future<void> toggle({required bool initializing}) async {
    final startedAt = _startRequestedAt;
    if (state.status == PipelineStatus.starting &&
        startedAt != null &&
        _clock().difference(startedAt) < doubleClickGrace) {
      return;
    }
    _errors.report(null);
    if (state.liveRunning) return stop();
    final selection = _selection;
    if (!state.canStart(selection, initializing: initializing)) return;
    // The snapshot session holds the worker loaded without whisper, so live
    // dubbing takes it over by starting afresh.
    if (state.running) {
      await stop();
      if (isClosed || state.status != PipelineStatus.idle) return;
    }
    _startRequestedAt = _clock();
    emit(
      state.copyWith(
        status: PipelineStatus.starting,
        session: PipelineSession.live,
        clearStartupProgress: true,
        startupStage: '',
        clearDetectedLanguage: true,
        clearSpokenVoice: true,
      ),
    );
    try {
      final settings = _settings.settings;
      final translation = selection.forTargetLanguage(ModelKind.translation)!.model;
      final speech = selection.forTargetLanguage(ModelKind.speech)!.model;
      final speechDirectory = await _modelRepository.directoryFor(speech);
      final recognition = selection.recognition!.model;
      await _appRepository.start(
        process: selection.requiresProcess ? state.selectedProcess : null,
        settings: settings,
        modelDirectories: {
          'whisper': path.join(
            await _modelRepository.directoryFor(recognition),
            recognition.primaryFileName,
          ),
          'translation': await _modelRepository.directoryFor(translation),
          'speech': path.join(speechDirectory, speech.primaryFileName),
          if (selection.needsVoiceConverter)
            'converter': await _modelRepository.directoryFor(selection.voiceConverter!.model),
        },
        speaker: selection.voice,
        translationPrefix: translation.translationPrefix ?? '',
        translateSpeech: selection.recognitionTranslatesSpeech,
        followSpeaker: selection.followsSpeaker,
        // The converter may be loaded only to hear who is speaking.
        revoice: selection.clonesVoice,
        maleVoices: speech.voicesOf(VoiceGender.male),
        femaleVoices: speech.voicesOf(VoiceGender.female),
        recognitionBackend: settings.backendFor(
          ComputeStage.recognition,
          _downloads.state.availability,
        ),
        translationBackend: settings.backendFor(
          ComputeStage.translation,
          _downloads.state.availability,
        ),
        voiceConversionBackend: settings.backendFor(
          ComputeStage.voiceConversion,
          _downloads.state.availability,
        ),
        runtimeDirectory: _downloads.state.runtimeDirectoryPath,
        // Kept per game, so one game's cast does not answer for another's.
        voiceBank: selection.keepsVoiceBank
            ? await _appRepository.voiceBankFileFor(state.selectedProcess?.name ?? '')
            : null,
      );
    } catch (exception) {
      if (isClosed) return;
      emit(state.copyWith(status: PipelineStatus.error));
      _errors.report(exception);
    }
  }

  /// Starts or ends the snapshot session, which loads only the translator
  /// and the voice and then waits for the player to select an area.
  Future<void> toggleSnapshot({required bool initializing}) async {
    final startedAt = _startRequestedAt;
    if (state.status == PipelineStatus.starting &&
        startedAt != null &&
        _clock().difference(startedAt) < doubleClickGrace) {
      return;
    }
    _errors.report(null);
    if (state.running) {
      // Live dubbing is ended from its own screen.
      if (state.session == PipelineSession.snapshot) await stop();
      return;
    }
    final selection = _selection;
    if (!state.canStartSnapshot(selection, initializing: initializing)) return;
    _startRequestedAt = _clock();
    emit(
      state.copyWith(
        status: PipelineStatus.starting,
        session: PipelineSession.snapshot,
        clearStartupProgress: true,
        startupStage: '',
        clearSpokenVoice: true,
        snapshotReading: false,
        snapshotMissed: false,
      ),
    );
    try {
      final settings = _settings.settings;
      final translation = selection.forTargetLanguage(ModelKind.translation)!.model;
      final speech = selection.forTargetLanguage(ModelKind.speech)!.model;
      final speechDirectory = await _modelRepository.directoryFor(speech);
      await _appRepository.startSnapshot(
        settings: settings,
        modelDirectories: {
          'translation': await _modelRepository.directoryFor(translation),
          'speech': path.join(speechDirectory, speech.primaryFileName),
        },
        // A selected line has no audio to follow the speaker by.
        speaker: selection.voice,
        translationPrefix: translation.translationPrefix ?? '',
        translationBackend: settings.backendFor(
          ComputeStage.translation,
          _downloads.state.availability,
        ),
        runtimeDirectory: _downloads.state.runtimeDirectoryPath,
      );
    } catch (exception) {
      if (isClosed) return;
      emit(state.copyWith(status: PipelineStatus.error));
      _errors.report(exception);
    }
  }

  /// Ends the session, paused or not, and gives the game its volume back.
  Future<void> stop() async {
    if (!state.running) return;
    _errors.report(null);
    emit(state.copyWith(status: PipelineStatus.stopping));
    var status = PipelineStatus.idle;
    try {
      await _appRepository.stop();
    } catch (exception) {
      status = PipelineStatus.error;
      _errors.report(exception);
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        status: status,
        clearStartupProgress: true,
        startupStage: '',
        // The detection, the devices and the voice belonged to the session
        // that just ended.
        clearDetectedLanguage: true,
        clearSpokenVoice: true,
        activeBackends: const {},
        snapshotReading: false,
      ),
    );
    // The worker has written its last voices by now.
    unawaited(_settings.refreshVoiceBank());
  }

  /// Rests a listening session without tearing it down: the models stay
  /// loaded, so resuming is instant rather than another minute of startup.
  Future<void> pause() async {
    if (state.status != PipelineStatus.listening || !state.liveRunning) return;
    try {
      await _appRepository.pause();
      if (!isClosed) emit(state.copyWith(status: PipelineStatus.paused));
    } catch (exception) {
      _errors.report(exception);
    }
  }

  Future<void> resume() async {
    if (state.status != PipelineStatus.paused) return;
    try {
      await _appRepository.resume();
      if (!isClosed) emit(state.copyWith(status: PipelineStatus.listening));
    } catch (exception) {
      _errors.report(exception);
    }
  }

  /// Empties the transcript. The pipeline is untouched: a running session
  /// keeps appending to the now-clear list.
  void clearTranscript() {
    if (state.transcript.isEmpty) return;
    emit(state.copyWith(transcript: const []));
  }

  /// Empties the list of selections, leaving the session alone.
  void clearSnapshots() {
    if (state.snapshots.isEmpty) return;
    emit(state.copyWith(snapshots: const []));
  }

  void _handleEvent(Map<String, Object?> event) {
    switch (event['type']) {
      case 'state':
        final status = switch (event['state']) {
          'ready' || 'listening' => PipelineStatus.listening,
          'starting' => PipelineStatus.starting,
          _ => PipelineStatus.idle,
        };
        emit(
          state.copyWith(
            status: status,
            clearStartupProgress: status != PipelineStatus.starting,
            startupStage: status == PipelineStatus.starting ? null : '',
          ),
        );
      case 'transcript':
        final entry = TranscriptEntry(
          original: event['original'] as String? ?? '',
          english: event['english'] as String? ?? '',
          translated: event['translated'] as String? ?? '',
          latency: Duration(milliseconds: event['latencyMs'] as int? ?? 0),
        );
        // A selection answers the player's request, not the running capture,
        // so it has a list of its own.
        if (event['snapshot'] == true) {
          emit(
            state.copyWith(
              snapshots: [entry, ...state.snapshots.take(49)],
              snapshotReading: false,
            ),
          );
        } else {
          emit(state.copyWith(transcript: [entry, ...state.transcript.take(49)]));
        }
      case 'snapshotReading':
        emit(state.copyWith(snapshotReading: true, snapshotMissed: false));
      case 'snapshot':
        // Text that was found stays in reading until its translation lands.
        if ((event['text'] as String? ?? '').isNotEmpty) return;
        emit(state.copyWith(snapshotReading: false, snapshotMissed: event['failed'] != true));
      case 'startup':
        emit(
          state.copyWith(
            startupProgress: (event['value'] as num?)?.toDouble(),
            clearStartupProgress: event['value'] == null,
            startupStage: event['stage'] as String? ?? '',
          ),
        );
      case 'language':
        final code = event['code'] as String?;
        emit(state.copyWith(detectedLanguage: code, clearDetectedLanguage: code == null));
      case 'voice':
        final name = event['name'] as String?;
        emit(state.copyWith(spokenVoice: name, clearSpokenVoice: name == null));
      case 'voiceBank':
        // The event carries this game's count; the settings show all games.
        unawaited(_settings.refreshVoiceBank());
      case 'backend':
        final stage = ComputeStage.values.where((value) => value.name == event['stage']);
        final backend = ComputeBackend.values.where((value) => value.name == event['backend']);
        if (stage.isEmpty || backend.isEmpty) return;
        emit(
          state.copyWith(
            activeBackends: {...state.activeBackends, stage.first: backend.first},
          ),
        );
      // A system-wide combination, pressed from inside the game.
      case 'hotkey':
        switch (event['action']) {
          case 'pause':
            unawaited(pause());
          case 'resume':
            unawaited(resume());
        }
      case 'error':
        // A phrase failing does not stop the capture, so the pipeline keeps
        // its state and the controls stay usable. Marking the session as
        // failed here used to leave it stuck: neither startable nor stoppable.
        // An event without a failure has nothing to show, and reporting null
        // would clear a banner raised a moment earlier.
        // Whatever failed, a selection still waiting will not be answered.
        if (state.snapshotReading) emit(state.copyWith(snapshotReading: false));
        if (event['failure'] case final failure?) _errors.report(failure);
    }
  }

  /// Stages a state a widget test wants to render without starting anything.
  @visibleForTesting
  void seed(LivePipelineState value) => emit(value);

  @override
  Future<void> close() {
    _events?.cancel();
    _appRepository.dispose();
    return super.close();
  }
}
