// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/repositories/settings_repository.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/compute_device.dart';
import 'package:lore_dub/src/domain/engine_event.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/settings_bloc.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/failure_cubit.dart';

import '../../../support/staged_dashboard.dart';
import '../../../support/fakes/fake_system_repository.dart';
import '../../../support/fakes/fake_session_repository.dart';

void main() {
  late _Disk disk;
  late SettingsRepository settings;
  late FakeSessionRepository engine;
  late FakeSystemRepository machine;
  late MemoryVoiceBank bank;
  late _Banner banner;

  setUp(() {
    disk = _Disk();
    settings = SettingsRepository(disk);
    engine = FakeSessionRepository();
    machine = FakeSystemRepository();
    bank = MemoryVoiceBank(4);
    banner = _Banner();
  });

  tearDown(() async {
    await settings.dispose();
    await engine.said.close();
  });

  SettingsBloc build() => SettingsBloc(engine, settings, banner, bank, machine);

  blocTest<SettingsBloc, SettingsState>(
    'reads the settings once and counts the kept voices as the screen opens',
    setUp: () => disk.stored = const AppSettings(targetLanguage: 'en'),
    build: build,
    act: (bloc) => bloc.add(const SettingsOpened()),
    verify: (bloc) {
      expect(bloc.state.settings.targetLanguage, 'en');
      expect(bloc.state.voiceBankSize, 4);
    },
  );

  blocTest<SettingsBloc, SettingsState>(
    'writes what the player set through the repository, and shows it from there',
    build: build,
    act: (bloc) => bloc.add(const SettingsChanged(AppSettings(ttsSpeed: 1.2))),
    verify: (bloc) {
      expect(disk.stored?.ttsSpeed, 1.2);
      expect(bloc.state.settings.ttsSpeed, 1.2);
    },
  );

  blocTest<SettingsBloc, SettingsState>(
    'builds a chosen language from the settings as they stand, not from a copy',
    build: build,
    act: (bloc) async {
      // Written elsewhere a moment before -- the canvas, the other screen.
      await settings.save(const AppSettings(ttsSpeed: 1.3));
      bloc.add(const TargetLanguageChosen('en'));
    },
    verify: (_) {
      expect(disk.stored?.targetLanguage, 'en');
      expect(disk.stored?.ttsSpeed, 1.3, reason: 'the other write is kept');
    },
  );

  blocTest<SettingsBloc, SettingsState>(
    'a device preset drops the pins, and a pin leaves the preset alone',
    build: build,
    act: (bloc) async {
      bloc.add(const StageBackendPinned(ComputeStage.recognition, ComputeBackend.vulkan));
      await pumpEventQueue();
      expect(settings.settings.backendOverride(ComputeStage.recognition), ComputeBackend.vulkan);
      bloc.add(const ComputeDeviceChosen(ComputeDevice.cpu));
    },
    verify: (_) {
      expect(settings.settings.computeDevice, ComputeDevice.cpu);
      expect(settings.settings.backendOverride(ComputeStage.recognition), isNull);
    },
  );

  blocTest<SettingsBloc, SettingsState>(
    'keeps the interpreter the search found',
    setUp: () => machine.python = r'C:\Python311\python.exe',
    build: build,
    act: (bloc) => bloc.add(const PythonSearched()),
    verify: (bloc) {
      expect(disk.stored?.pythonExecutable, r'C:\Python311\python.exe');
      expect(bloc.state.searchingPython, isFalse);
      expect(banner.reported, isNull);
    },
  );

  blocTest<SettingsBloc, SettingsState>(
    'searches once however often it is asked while it searches',
    setUp: () => machine.holdSearch = Completer<void>(),
    build: build,
    act: (bloc) async {
      bloc
        ..add(const PythonSearched())
        ..add(const PythonSearched());
      await pumpEventQueue();
      expect(bloc.state.searchingPython, isTrue);
      machine.holdSearch!.complete();
    },
    verify: (_) => expect(machine.searches, 1),
  );

  blocTest<SettingsBloc, SettingsState>(
    'says why no interpreter would do, and keeps the one it had',
    setUp: () => disk.stored = const AppSettings(pythonExecutable: r'C:\old\python.exe'),
    build: build,
    act: (bloc) async {
      await settings.load();
      bloc.add(const PythonSearched());
    },
    verify: (bloc) {
      expect(banner.reported, isNotNull);
      expect(settings.settings.pythonExecutable, r'C:\old\python.exe');
      expect(bloc.state.searchingPython, isFalse);
    },
  );

  blocTest<SettingsBloc, SettingsState>(
    'clears the kept voices and counts them again',
    build: build,
    act: (bloc) => bloc.add(const VoiceBankCleared()),
    verify: (bloc) {
      expect(bank.cleared, isTrue);
      expect(bloc.state.voiceBankSize, 0);
    },
  );

  blocTest<SettingsBloc, SettingsState>(
    'counts the voices again as a session comes to rest',
    build: build,
    act: (bloc) async {
      bank.count = 7;
      engine.said.add(const SessionStateChanged(status: PipelineStatus.idle));
    },
    verify: (bloc) => expect(bloc.state.voiceBankSize, 7),
  );
}

/// The settings file with no disk behind it.
class _Disk extends SettingsService {
  AppSettings? stored;

  @override
  Future<AppSettings> load() async => stored ?? const AppSettings();

  @override
  Future<void> save(AppSettings settings) async => stored = settings;
}

class _Banner implements FailureSink {
  Object? reported;

  @override
  void report(Object? error) => reported = error ?? reported;
}
