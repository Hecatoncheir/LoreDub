// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/repositories/session_repository.dart';
import 'package:lore_dub/src/data/repositories/settings_repository.dart';
import 'package:lore_dub/src/data/repositories/update_repository.dart';
import 'package:lore_dub/src/data/services/artifact_downloader.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/domain/app_release.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/session_coordinator.dart';
import 'package:lore_dub/src/ui/shell/bloc/failure_cubit.dart';
import 'package:lore_dub/src/ui/shell/bloc/update_bloc.dart';

import '../../../../support/fakes/memory_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Releases releases;
  late SettingsRepository settings;
  late SessionCoordinator sessions;
  late _Banner banner;

  final release = AppRelease(
    version: '0.3.0',
    page: Uri.parse('https://github.com/Hecatoncheir/LoreDub/releases/tag/v0.3.0'),
    installer: ReleaseInstaller(
      name: 'LoreDub-0.3.0-windows-x64-setup.exe',
      url: Uri.parse('https://github.com/Hecatoncheir/LoreDub/releases/download/v0.3.0/setup.exe'),
      size: 181234513,
    ),
  );
  final available = UpdateState(
    status: UpdateStatus.available,
    currentVersion: '0.2.1',
    release: release,
    installable: true,
  );

  setUp(() {
    releases = _Releases();
    settings = SettingsRepository(SettingsService())
      ..seed(const AppSettings(modelProxyUrl: 'http://proxy:8080'));
    sessions = SessionCoordinator();
    banner = _Banner();
  });

  tearDown(() async {
    await settings.dispose();
    await sessions.dispose();
  });

  UpdateBloc build() =>
      UpdateBloc(releases, settings, SessionRepository(memoryEngine()), sessions, banner);

  blocTest<UpdateBloc, UpdateState>(
    'finds a newer release through the proxy, and marks the startup check as news',
    setUp: () => releases.latest = release,
    build: build,
    act: (bloc) => bloc.add(const UpdatesChecked(announce: true)),
    verify: (bloc) {
      expect(bloc.state.hasUpdate, isTrue);
      expect(bloc.state.currentVersion, '0.2.1');
      expect(bloc.state.installable, isTrue);
      expect(bloc.state.announce, isTrue);
      expect(releases.proxies, ['http://proxy:8080']);
    },
  );

  blocTest<UpdateBloc, UpdateState>(
    'a check the player asked for is answered on the screen, not in a toast',
    setUp: () => releases.latest = release,
    build: build,
    act: (bloc) => bloc.add(const UpdatesChecked()),
    verify: (bloc) {
      expect(bloc.state.hasUpdate, isTrue);
      expect(bloc.state.announce, isFalse);
    },
  );

  blocTest<UpdateBloc, UpdateState>(
    'says it is current when nothing newer is published',
    setUp: () => releases.latest = AppRelease(version: '0.2.1', page: release.page),
    build: build,
    act: (bloc) => bloc.add(const UpdatesChecked(announce: true)),
    verify: (bloc) {
      expect(bloc.state.status, UpdateStatus.current);
      expect(bloc.state.announce, isFalse, reason: 'there is no news');
    },
  );

  blocTest<UpdateBloc, UpdateState>(
    'says the check failed rather than raising the banner',
    setUp: () => releases.fails = true,
    build: build,
    act: (bloc) => bloc.add(const UpdatesChecked()),
    verify: (bloc) {
      expect(bloc.state.status, UpdateStatus.failed);
      expect(banner.reported, isNull);
    },
  );

  blocTest<UpdateBloc, UpdateState>(
    'raises the toast in the words it is handed, and only once',
    seed: () => available.copyWith(announce: true),
    build: build,
    act: (bloc) => bloc.add(const UpdateAnnounced(title: 'Новая версия', body: '0.3.0')),
    verify: (bloc) {
      expect(releases.announced, ['Новая версия: 0.3.0']);
      expect(bloc.state.announce, isFalse);
    },
  );

  blocTest<UpdateBloc, UpdateState>(
    'downloads the setup and waits for the restart',
    seed: () => available,
    build: build,
    act: (bloc) => bloc.add(const UpdateInstallAsked()),
    expect: () => [
      _sameAs(available.copyWith(installProgress: 0)),
      _sameAs(available.copyWith(installProgress: 0.5)),
      _sameAs(available.copyWith(installProgress: 1)),
      _sameAs(available.copyWith(installerPath: r'C:\updates\LoreDub-0.3.0-windows-x64-setup.exe')),
    ],
    verify: (_) => expect(releases.downloaded, ['LoreDub-0.3.0-windows-x64-setup.exe']),
  );

  blocTest<UpdateBloc, UpdateState>(
    'opens the release page for a copy the setup cannot replace',
    seed: () => available.copyWith(installable: false),
    build: build,
    act: (bloc) => bloc.add(const UpdateInstallAsked()),
    verify: (_) {
      expect(releases.downloaded, isEmpty);
      expect(releases.opened, [release.page]);
    },
  );

  blocTest<UpdateBloc, UpdateState>(
    'restarts into the downloaded setup',
    seed: () => available.copyWith(installerPath: r'C:\updates\setup.exe'),
    build: build,
    act: (bloc) => bloc.add(const UpdateRestartAsked()),
    verify: (_) => expect(releases.restarted, [r'C:\updates\setup.exe']),
  );
}

/// [UpdateState] has no equality of its own; the step is told by what it
/// shows.
Matcher _sameAs(UpdateState expected) => isA<UpdateState>()
    .having((state) => state.status, 'status', expected.status)
    .having((state) => state.installProgress, 'progress', expected.installProgress)
    .having((state) => state.installerPath, 'setup', expected.installerPath);

/// The releases, answered in memory: nothing reaches GitHub, nothing is
/// downloaded, and nothing closes the test runner.
class _Releases extends Fake implements UpdateRepository {
  AppRelease? latest;
  bool fails = false;
  final proxies = <String>[];
  final announced = <String>[];
  final downloaded = <String>[];
  final opened = <Uri>[];
  final restarted = <String>[];

  @override
  Future<String> currentVersion() async => '0.2.1';

  @override
  Future<AppRelease?> latestRelease({String proxyUrl = ''}) async {
    proxies.add(proxyUrl);
    if (fails) throw StateError('rate limited');
    return latest;
  }

  @override
  bool get canInstall => true;

  @override
  Future<String?> downloadedInstaller(ReleaseInstaller installer) async => null;

  @override
  Future<void> announce({required String title, required String body}) async =>
      announced.add('$title: $body');

  @override
  Future<String> downloadInstaller(
    ReleaseInstaller installer, {
    required DownloadProgress onProgress,
    String proxyUrl = '',
  }) async {
    onProgress(0.5);
    onProgress(1);
    downloaded.add(installer.name);
    return 'C:\\updates\\${installer.name}';
  }

  @override
  Future<void> openPage(Uri page) async => opened.add(page);

  @override
  Future<void> restartInto(String setup) async => restarted.add(setup);
}

class _Banner implements FailureSink {
  Object? reported;

  @override
  void report(Object? error) => reported = error ?? reported;
}
