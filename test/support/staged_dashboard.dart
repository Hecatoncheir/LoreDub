// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lore_dub/src/data/repositories/session_repository.dart';
import 'package:lore_dub/src/data/repositories/cast_repository.dart';
import 'package:lore_dub/src/data/repositories/install_repository.dart';
import 'package:lore_dub/src/data/repositories/model_repository.dart';
import 'package:lore_dub/src/data/repositories/runtime_repository.dart';
import 'package:lore_dub/src/data/repositories/settings_repository.dart';
import 'package:lore_dub/src/data/repositories/sources_repository.dart';
import 'package:lore_dub/src/data/repositories/update_repository.dart';
import 'package:lore_dub/src/domain/model_selection.dart';
import 'package:lore_dub/src/domain/session_coordinator.dart';
import 'package:lore_dub/src/ui/characters/bloc/cast_bloc.dart';
import 'package:lore_dub/src/ui/models/bloc/downloads_bloc.dart';
import 'package:lore_dub/src/ui/glossary/bloc/glossary_bloc.dart';
import 'package:lore_dub/src/ui/common/bloc/session_bloc.dart';
import 'package:lore_dub/src/ui/graph/bloc/pipeline_facts_bloc.dart';
import 'package:lore_dub/src/ui/graph/bloc/pipeline_graph_bloc.dart';
import 'package:lore_dub/src/ui/settings/bloc/settings_bloc.dart';
import 'package:lore_dub/src/ui/shell/bloc/failure_cubit.dart';
import 'package:lore_dub/src/ui/shell/bloc/navigation_cubit.dart';
import 'package:lore_dub/src/ui/shell/bloc/startup_cubit.dart';
import 'package:lore_dub/src/ui/shell/bloc/update_bloc.dart';
import 'package:lore_dub/src/ui/common/bloc/sources_bloc.dart';
import 'package:lore_dub/src/ui/common/bloc/transcript_bloc.dart';
import 'package:lore_dub/src/ui/characters/bloc/voice_capture_bloc.dart';
import 'package:lore_dub/src/data/repositories/glossary_repository.dart';
import 'package:lore_dub/src/data/repositories/scheme_repository.dart';
import 'package:lore_dub/src/data/repositories/system_repository.dart';
import 'package:lore_dub/src/data/repositories/voice_bank_repository.dart';
import 'package:lore_dub/src/data/services/native_engine_service.dart';
import 'package:lore_dub/src/domain/compute_device.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/pipeline_graph.dart';
import 'package:lore_dub/src/domain/saved_pipeline.dart';

import 'memory_cast.dart';

import 'package:lore_dub/src/domain/app_release.dart';

export 'fakes/memory_glossary.dart';
export 'fakes/memory_schemes.dart';
export 'fakes/memory_voice_bank.dart';
import 'fakes/memory_glossary.dart';
import 'fakes/memory_schemes.dart';
import 'fakes/memory_voice_bank.dart';
import 'fakes/memory_native.dart';

import 'package:lore_dub/src/domain/glossary.dart';

/// Every screen's state, built by hand for a test to stage and then put on
/// the screen through [provide].
///
/// The application builds them in `DashboardProviders`, each out of the
/// repositories above it, and runs their first reads there. A widget test
/// wants the opposite: states put in place without anything read, and a
/// handle on each to seed and to look at. Nothing here runs a load.
///
/// It stays beside the mocked blocs rather than giving way to them: a
/// screen tested over a `MockBloc` is put on the screen through it as well
/// (`StagedDashboard(glossaryBloc: ...)`), and the canvas and the inspector
/// drive the real blocs it builds.
class StagedDashboard {
  ///
  /// The repositories a test does not hand over are made over the disk as
  /// the application's are, and over an engine that answers from memory
  /// ([memoryEngine]) rather than the native library, which would register
  /// hotkeys and draw on the screen; one that is handed over is usually a
  /// fake that keeps its files in memory.
  StagedDashboard(
    this.sessionRepository,
    this.settingsRepository,
    ModelRepository modelRepository,
    RuntimeRepository runtimeRepository,
    UpdateRepository updateRepository, {
    NativeEngineService? engine,
    SystemRepository? system,
    VoiceBankRepository? voiceBank,
    SchemeRepository? schemes,
    GlossaryRepository? glossaryRepository,
    CastRepository? cast,
    GlossaryBloc? glossaryBloc,
    CastBloc? castBloc,
    VoiceCaptureBloc? captureBloc,
    DownloadsBloc? downloadsBloc,
    SessionBloc? sessionBloc,
    TranscriptBloc? transcriptBloc,
    UpdateBloc? updateBloc,
  }) {
    final native = engine ?? memoryEngine();
    this.system = system ?? SystemRepository(native);
    // Kept in memory unless a test hands one over: a bloc waits for its
    // handlers as it closes, and the real bank reads a disk that does not
    // answer inside a widget test's fake time -- counted as a session came
    // to rest, it held every teardown for ever.
    this.voiceBank = voiceBank ?? MemoryVoiceBank();
    // In memory, as the cast and the bank are: the canvas writes its
    // arrangement as it is drawn on, and the cards are read before it
    // opens -- a real file answers neither inside a widget test.
    this.schemes = schemes ?? MemorySchemes();
    // In memory for the same reason: the canvas reads the glossary before
    // it draws the packs on it.
    this.glossaryRepository =
        glossaryRepository ?? GlossaryRepository(settingsRepository, native, MemoryGlossary());
    this.cast = cast ?? CastRepository(native, MemoryCharacters());
    installed = InstallRepository(modelRepository, runtimeRepository);
    sourcesRepository = SourcesRepository(this.system);
    updates =
        updateBloc ??
        UpdateBloc(
          updateRepository,
          settingsRepository,
          sessionRepository,
          sessions,
          failures,
        );
    // The first load has come back, as it has on any screen a test looks
    // at; `startup_cubit_test.dart` is where it is run.
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    startup.emit(false);
    settings = SettingsBloc(
      sessionRepository,
      settingsRepository,
      failures,
      this.voiceBank,
      this.system,
    );
    downloads =
        downloadsBloc ??
        DownloadsBloc(modelRepository, runtimeRepository, installed, settingsRepository, failures);
    sources = SourcesBloc(sourcesRepository, failures);
    pipeline =
        sessionBloc ??
        SessionBloc(
          sessionRepository,
          modelRepository,
          settingsRepository,
          installed,
          sourcesRepository,
          failures,
          sessions,
          this.voiceBank,
        );
    transcript = transcriptBloc ?? TranscriptBloc(sessionRepository, sessions, failures);
    cards = castBloc ?? CastBloc(this.cast, failures);
    voices =
        captureBloc ??
        VoiceCaptureBloc(
          sessionRepository,
          modelRepository,
          settingsRepository,
          installed,
          failures,
          sessions,
          this.cast,
        );
    // A screen test hands a mock over: what the screen shows is then what
    // the test says, and what it sends is kept.
    glossary = glossaryBloc ?? GlossaryBloc(this.glossaryRepository, failures);
    graph = PipelineGraphBloc(
      this.schemes,
      settingsRepository,
      this.cast,
      this.glossaryRepository,
      installed,
      sessions,
      failures,
    );
    facts = PipelineFactsBloc(
      settingsRepository,
      installed,
      this.cast,
      this.glossaryRepository,
      sourcesRepository,
      sessions,
    );
  }

  final SessionRepository sessionRepository;
  final SettingsRepository settingsRepository;
  final sessions = SessionCoordinator();
  late final SystemRepository system;
  late final VoiceBankRepository voiceBank;
  late final SchemeRepository schemes;
  late final GlossaryRepository glossaryRepository;
  late final InstallRepository installed;
  late final CastRepository cast;
  late final SourcesRepository sourcesRepository;

  /// The banner every bloc reports what went wrong to.
  final failures = FailureCubit();
  final navigation = NavigationCubit();

  /// Staged as done: the first load is `StartupCubit`'s own test.
  late final startup = StartupCubit(settingsRepository, installed, system, failures);
  late final UpdateBloc updates;
  late final SettingsBloc settings;
  late final DownloadsBloc downloads;
  late final SourcesBloc sources;
  late final SessionBloc pipeline;
  late final TranscriptBloc transcript;

  /// The cards and the packs of the characters screen.
  late final CastBloc cards;

  /// The characters screen's side of the engine.
  late final VoiceCaptureBloc voices;
  late final GlossaryBloc glossary;
  late final PipelineGraphBloc graph;
  late final PipelineFactsBloc facts;

  /// Stages what is on disk and what the machine can run it on, where every
  /// screen reads it: the repository, which the downloads bloc follows an
  /// event later with rows that have nothing arriving. A row with a
  /// download under way is a mock's to stage (`downloadsShowing`).
  void stageInstalled({
    List<ModelInstallState> models = const [],
    ComputeAvailability availability = const ComputeAvailability(),
  }) => installed.seed(
    InstalledParts(
      models: [
        for (final install in models)
          ModelInstallState(model: install.model, installed: install.installed),
      ],
      availability: availability,
    ),
  );

  /// Stages the dubbing screens' session as a test says it stands -- what
  /// `blocTest`'s `seed` does -- and tells the coordinator, as the bloc's
  /// own `onChange` does for every state it moves to.
  void stageSession(SessionState value) =>
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      pipeline.emit(value);

  /// Stages the canvas as it would open on [layout] and a shelf of
  /// [shelf]: they are put where it reads them from, and it is opened the
  /// way the application opens it. It is drawn an event later.
  void stageScheme({
    PipelineLayout layout = PipelineLayout.standard,
    List<SavedPipeline> shelf = const [],
  }) {
    if (schemes case final MemorySchemes memory) {
      memory
        ..layout = layout
        ..shelf = PipelineLibrary(pipelines: shelf);
    }
    graph.add(const PipelineGraphOpened());
  }

  /// Stages what is written down in the glossary, where every screen reads
  /// it: the repository, which the glossary screen and the canvas follow.
  void stageGlossary(Glossary value) => glossaryRepository.seed(value);

  /// Stages what is known about newer versions -- what `blocTest`'s
  /// `seed` does. What the version row sends is a mock's
  /// (`updatesShowing`), and the check itself `update_bloc_test.dart`'s.
  void stageUpdates(UpdateState value) =>
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      updates.emit(value);

  /// Stages the section open, and the half of Эфир where it is Эфир.
  void stageSection(DashboardSection section, [LiveView liveView = LiveView.dubbing]) {
    navigation.showOnLive(liveView);
    navigation.selectSection(section);
  }

  /// Stages what the dubbing screens' sessions have said.
  void stageLists(TranscriptState value) =>
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      transcript.emit(value);

  /// What the settings and the installed packages together decided.
  ModelSelection get selection =>
      ModelSelection(models: downloads.state.models, settings: settings.settings);

  /// [child] under these states and the repositories they were made of,
  /// the way `DashboardProviders` puts the application's.
  Widget provide(Widget child) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider.value(value: sessionRepository),
      RepositoryProvider.value(value: settingsRepository),
      RepositoryProvider.value(value: system),
      RepositoryProvider.value(value: voiceBank),
      RepositoryProvider.value(value: schemes),
      RepositoryProvider.value(value: glossaryRepository),
      RepositoryProvider.value(value: installed),
      RepositoryProvider.value(value: cast),
      RepositoryProvider.value(value: sourcesRepository),
      RepositoryProvider.value(value: sessions),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider.value(value: failures),
        BlocProvider.value(value: navigation),
        BlocProvider.value(value: startup),
        BlocProvider.value(value: updates),
        BlocProvider.value(value: settings),
        BlocProvider.value(value: downloads),
        BlocProvider.value(value: sources),
        BlocProvider.value(value: pipeline),
        BlocProvider.value(value: transcript),
        BlocProvider.value(value: cards),
        BlocProvider.value(value: voices),
        BlocProvider.value(value: glossary),
        BlocProvider.value(value: graph),
        BlocProvider.value(value: facts),
      ],
      child: child,
    ),
  );

  Future<void> dispose() async {
    await facts.close();
    await graph.close();
    await glossary.close();
    await voices.close();
    await cards.close();
    await transcript.close();
    await pipeline.close();
    await sources.close();
    await downloads.close();
    await settings.close();
    await updates.close();
    await startup.close();
    await navigation.close();
    await failures.close();
    await sessions.dispose();
  }
}
