// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'data/repositories/cast_repository.dart';
import 'data/repositories/glossary_repository.dart';
import 'data/repositories/install_repository.dart';
import 'data/repositories/model_repository.dart';
import 'data/repositories/runtime_repository.dart';
import 'data/repositories/scheme_repository.dart';
import 'data/repositories/session_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/sources_repository.dart';
import 'data/repositories/system_repository.dart';
import 'data/repositories/update_repository.dart';
import 'data/repositories/voice_bank_repository.dart';
import 'data/services/character_service.dart';
import 'data/services/glossary_service.dart';
import 'data/services/local_inference_service.dart';
import 'data/services/model_storage_service.dart';
import 'data/services/native_bridge.dart';
import 'data/services/native_engine_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/pipeline_graph_service.dart';
import 'data/services/pipeline_library_service.dart';
import 'data/services/python_discovery.dart';
import 'data/services/runtime_storage_service.dart';
import 'data/services/settings_service.dart';
import 'data/services/update_installer.dart';
import 'data/services/update_service.dart';
import 'data/services/voice_bank_service.dart';
import 'domain/session_coordinator.dart';

/// Everything the application is made of below its screens, built once and
/// in one place: services, then the repositories over them.
///
/// Each file the player's work is kept in has one service, handed to every
/// repository that reads or writes it: a file's writes are put in order by
/// its service, and two services over one file would each keep an order of
/// their own. Nothing here is a default -- every repository is handed what
/// it stands on, so what the application runs on can be read off this file.
/// The screens' blocs are built from these in `DashboardProviders`.
///
/// The bridge is the one exception, and only for the tests: the application
/// runs on the library itself, and a test that pumps the whole of it hands
/// over a bridge that answers from memory, or it would register the
/// player's hotkeys and draw over the screen of whoever runs the tests.
class AppComposition {
  AppComposition({this._native = const NativeBridge()});

  final NativeBridge _native;

  // The files the player's work is kept in, one service each.
  final _characters = CharacterService();
  final _glossary = GlossaryService();
  final _layout = PipelineGraphService();
  final _shelf = PipelineLibraryService();

  /// The one engine, which the sessions run on and several repositories
  /// tell what changed while one runs.
  late final engine = NativeEngineService(
    inference: LocalInferenceService(),
    native: _native,
  );

  /// One settings file, read and published in one place: everything that
  /// follows a setting listens here rather than being told.
  final settings = SettingsRepository(SettingsService());

  /// The sessions that engine runs, and the files a start writes into them.
  late final sessions = SessionRepository(engine, _characters, _glossary, _layout);

  /// What this machine has: the processes, the monitors, the adapters.
  late final system = SystemRepository(engine, PythonDiscovery());
  final voiceBank = VoiceBankRepository(VoiceBankService());
  late final schemes = SchemeRepository(layout: _layout, shelf: _shelf);
  late final glossary = GlossaryRepository(settings, engine, _glossary);
  final models = ModelRepository(ModelStorageService());
  final runtimes = RuntimeRepository(RuntimeStorageService());
  final updates = UpdateRepository(UpdateService(), NotificationService(), UpdateInstaller());

  /// What is on disk and what the machine can run it on, read once and
  /// told to everyone who cares.
  late final installed = InstallRepository(models, runtimes);

  /// The player's own cards, which two screens work on.
  late final cast = CastRepository(engine, _characters);

  /// The game every screen listens to, and where the monitors stand.
  late final sources = SourcesRepository(system);

  /// Which screen may hold the one worker, and what the engine is doing.
  final coordinator = SessionCoordinator();

  /// Lets go of what publishes, and of the engine they share last.
  void dispose() {
    unawaited(
      Future.wait([
        coordinator.dispose(),
        sources.dispose(),
        cast.dispose(),
        installed.dispose(),
        settings.dispose(),
      ]).whenComplete(sessions.dispose),
    );
  }
}
