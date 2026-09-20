// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/repositories/settings_repository.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stands on the defaults until the disk has been read', () {
    SharedPreferences.setMockInitialValues({});

    expect(SettingsRepository(SettingsService()).settings, const AppSettings());
  });

  test('tells everyone who is listening what was read', () async {
    SharedPreferences.setMockInitialValues({'targetLanguage': 'ru', 'cpuThreads': 6});
    final repository = SettingsRepository(SettingsService());
    final heard = <AppSettings>[];
    final listening = repository.changes.listen(heard.add);
    addTearDown(listening.cancel);

    await repository.load();
    // A broadcast controller hands its value over in a microtask.
    await Future<void>.delayed(Duration.zero);

    expect(repository.settings.cpuThreads, 6);
    expect(heard.single.cpuThreads, 6);
  });

  test('publishes a write before the disk has heard of it', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SettingsRepository(SettingsService());

    final writing = repository.save(const AppSettings(cpuThreads: 3));

    expect(
      repository.settings.cpuThreads,
      3,
      reason: 'what the player just did is on screen before it is stored',
    );
    await writing;
    expect((await SettingsService().load()).cpuThreads, 3, reason: 'and stored after');
  });

  test('a listener that came late is told the next change, not the last', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SettingsRepository(SettingsService());
    await repository.save(const AppSettings(cpuThreads: 3));

    final heard = <int>[];
    final listening = repository.changes.listen((value) => heard.add(value.cpuThreads));
    addTearDown(listening.cancel);
    await Future<void>.delayed(Duration.zero);

    // What holds already is read off `settings`; the stream is for what
    // happens next.
    expect(heard, isEmpty);
    expect(repository.settings.cpuThreads, 3);

    await repository.save(const AppSettings(cpuThreads: 4));
    await Future<void>.delayed(Duration.zero);

    expect(heard, [4]);
  });
}
