// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

part of 'session_bloc.dart';

/// The dubbing screens' session: what it is doing and what it chose to run
/// on. What it has said is `TranscriptBloc`'s.
class SessionState extends Equatable {
  const SessionState({
    this.status = PipelineStatus.idle,
    this.startupProgress,
    this.startupStage = '',
    this.detectedLanguage,
    this.spokenVoice,
    this.activeBackends = const {},
    this.session = PipelineSession.live,
    this.screenReading = ScreenReading.both,
    this.frameMissed = false,
  });

  final PipelineStatus status;

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

  /// What the running session of the Screen page reads. Meaningless unless
  /// [session] is `PipelineSession.screen`: it is what tells the three
  /// buttons of that page which of them is the one running.
  final ScreenReading screenReading;

  /// Whether the last frame drawn over the game missed its window, so the
  /// subtitles go on being read where they were.
  final bool frameMissed;

  /// A paused session is still a session: its settings stay locked and its
  /// models loaded.
  bool get running =>
      status == PipelineStatus.starting ||
      status == PipelineStatus.listening ||
      status == PipelineStatus.paused;

  /// Live dubbing is up, starting or resting.
  bool get liveRunning => running && session == PipelineSession.live;

  /// A live session up and answering to pause or stop, which is when the
  /// start button gives its place to the session's two controls.
  bool get liveUp =>
      session == PipelineSession.live &&
      (status == PipelineStatus.listening || status == PipelineStatus.paused);

  /// A live session still loading its models.
  bool get liveStarting => session == PipelineSession.live && status == PipelineStatus.starting;

  /// The snapshot session is up and waiting for a selection.
  bool get screenRunning => session == PipelineSession.screen && status == PipelineStatus.listening;

  /// The scene session is up, placing the voices of the game without dubbing
  /// a word of it.
  bool get sceneRunning => session == PipelineSession.scene && running;

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

  /// Neither a running snapshot session nor one placing the voices of the
  /// scene stands in the way: starting live dubbing takes the worker over.
  ///
  /// [process] is the game named, which is not this state's: every screen
  /// shares it (`SourcesRepository`).
  bool canStart(
    ModelSelection selection, {
    required bool initializing,
    required GameProcess? process,
  }) =>
      !initializing &&
      (status == PipelineStatus.idle || screenRunning || sceneRunning) &&
      (!selection.requiresProcess || process != null) &&
      // Taken apart on the graph, the pipeline has nothing to work on.
      selection.settings.captureRouted &&
      selection.requiredModelsInstalled;

  /// The scene session needs the converter, a bank to keep the voices it
  /// founds in, and — like dubbing — a game to listen to.
  bool canStartScene(
    ModelSelection selection, {
    required bool initializing,
    required GameProcess? process,
  }) =>
      !initializing &&
      (status == PipelineStatus.idle || sceneRunning) &&
      (!selection.requiresProcess || process != null) &&
      selection.tracksSpeakers;

  /// The screen session needs its pair of models, and then what the
  /// reading itself asks for: a key to pick a snippet out with, and -- for
  /// the frame, unless the whole screen is what it reads -- the game whose
  /// window it is taken out of.
  ///
  /// A session of another reading is no obstacle: pressing the button of
  /// one ends the other and starts this one.
  bool canStartScreen(
    ModelSelection selection, {
    required bool initializing,
    required GameProcess? process,
    ScreenReading reading = ScreenReading.both,
  }) =>
      !initializing &&
      (status == PipelineStatus.idle || screenRunning) &&
      selection.screenModelsInstalled &&
      (!reading.readsSubtitles || selection.settings.readsWholeScreen || process != null) &&
      (!reading.readsSnippets || selection.settings.snapshotHotkey != null);

  SessionState copyWith({
    PipelineStatus? status,
    double? startupProgress,
    bool clearStartupProgress = false,
    String? startupStage,
    String? detectedLanguage,
    bool clearDetectedLanguage = false,
    String? spokenVoice,
    bool clearSpokenVoice = false,
    Map<ComputeStage, ComputeBackend>? activeBackends,
    PipelineSession? session,
    ScreenReading? screenReading,
    bool? frameMissed,
  }) => SessionState(
    status: status ?? this.status,
    startupProgress: clearStartupProgress ? null : startupProgress ?? this.startupProgress,
    startupStage: startupStage ?? this.startupStage,
    detectedLanguage: clearDetectedLanguage ? null : detectedLanguage ?? this.detectedLanguage,
    spokenVoice: clearSpokenVoice ? null : spokenVoice ?? this.spokenVoice,
    activeBackends: activeBackends ?? this.activeBackends,
    session: session ?? this.session,
    screenReading: screenReading ?? this.screenReading,
    frameMissed: frameMissed ?? this.frameMissed,
  );

  @override
  List<Object?> get props => [
    status,
    startupProgress,
    startupStage,
    detectedLanguage,
    spokenVoice,
    activeBackends,
    session,
    screenReading,
    frameMissed,
  ];
}
