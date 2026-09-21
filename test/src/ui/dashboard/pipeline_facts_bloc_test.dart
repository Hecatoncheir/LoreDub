// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/repositories/cast_repository.dart';
import 'package:lore_dub/src/data/repositories/install_repository.dart';
import 'package:lore_dub/src/data/repositories/model_repository.dart';
import 'package:lore_dub/src/data/repositories/runtime_repository.dart';
import 'package:lore_dub/src/data/repositories/settings_repository.dart';
import 'package:lore_dub/src/data/repositories/sources_repository.dart';
import 'package:lore_dub/src/data/services/model_catalog.dart';
import 'package:lore_dub/src/data/services/model_storage_service.dart';
import 'package:lore_dub/src/data/services/native_engine_service.dart';
import 'package:lore_dub/src/data/services/runtime_storage_service.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/capture_sources.dart';
import 'package:lore_dub/src/domain/character.dart';
import 'package:lore_dub/src/domain/compute_device.dart';
import 'package:lore_dub/src/domain/game_process.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart';
import 'package:lore_dub/src/domain/session_coordinator.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/pipeline_facts_bloc.dart';
import 'package:lore_dub/src/data/repositories/system_repository.dart';

void main() {
  const game = GameProcess(pid: 42, name: 'game.exe', path: 'C:/game.exe');

  late SettingsRepository settings;
  late InstallRepository installed;
  late CastRepository cast;
  late SourcesRepository sources;
  late SessionCoordinator sessions;
  late PipelineFactsBloc facts;

  setUp(() {
    settings = SettingsRepository(SettingsService());
    installed = InstallRepository(
      ModelRepository(ModelStorageService()),
      RuntimeRepository(RuntimeStorageService()),
    );
    final engine = NativeEngineService();
    cast = CastRepository(engine);
    sources = SourcesRepository(SystemRepository(engine));
    sessions = SessionCoordinator();
    facts = PipelineFactsBloc(settings, installed, cast, sources, sessions);
  });

  tearDown(() async {
    await facts.close();
    await sessions.dispose();
  });

  test('starts from what the five sources say now', () {
    expect(facts.state.running, isFalse);
    expect(facts.state.process, isNull);
    expect(facts.state.characters, isEmpty);
  });

  test('follows each of the things the scheme is drawn from', () async {
    settings.seed(const AppSettings(voice: 'kseniya'));
    sources.seed(const CaptureSources(processes: [game], selected: game));
    cast.seed(
      const CharacterLibrary(
        characters: [
          Character(id: 'a1', name: 'Стражник', vector: [0.2]),
        ],
      ),
    );
    sessions
      ..reportPipeline(
        status: PipelineStatus.paused,
        session: PipelineSession.live,
        backends: const {ComputeStage.recognition: ComputeBackend.cuda},
      )
      ..reportCast(running: true);
    await pumpEventQueue();

    final now = facts.state;
    expect(now.settings.voice, 'kseniya');
    expect(now.process, same(game));
    expect(now.characters.single.id, 'a1');
    expect(now.running, isTrue);
    expect(now.paused, isTrue);
    expect(now.recordingVoice, isTrue);
    expect(now.activeBackends[ComputeStage.recognition], ComputeBackend.cuda);
  });

  test('a download on its way does not redraw the scheme', () async {
    // The canvas answers every new facts with a frame; a download ticks a
    // hundred times, and only its end changes what can be drawn.
    final model = modelCatalog.first;
    installed.seed(InstalledParts(models: [ModelInstallState(model: model)]));
    await pumpEventQueue();
    final before = facts.state;

    installed.seed(InstalledParts(models: [ModelInstallState(model: model)]));
    await pumpEventQueue();
    expect(facts.state, same(before), reason: 'nothing arrived');

    installed.seed(InstalledParts(models: [ModelInstallState(model: model, installed: true)]));
    await pumpEventQueue();
    expect(facts.state, isNot(same(before)), reason: 'the package is there now');
  });

  test('another game in the list is not another scheme', () async {
    sources.seed(const CaptureSources(processes: [game], selected: game));
    await pumpEventQueue();
    final before = facts.state;

    sources.seed(
      const CaptureSources(
        processes: [
          game,
          GameProcess(pid: 7, name: 'other.exe', path: 'C:/other.exe'),
        ],
        selected: game,
      ),
    );
    await pumpEventQueue();

    expect(facts.state, same(before));
  });
}
