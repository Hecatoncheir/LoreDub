// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

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

  test('reads the file once, whoever asks first', () async {
    // The glossary awaits the settings for the language its built-in
    // packs are written in, and so may anyone else; asked again, the read
    // already in flight is what they get rather than a second one.
    SharedPreferences.setMockInitialValues({'cpuThreads': 5});
    final repository = SettingsRepository(SettingsService());

    final both = await Future.wait([repository.load(), repository.load()]);

    expect(both.first, same(both.last));
    expect(repository.settings.cpuThreads, 5);
  });

  test('staged settings count as read, so no disk puts them back', () async {
    SharedPreferences.setMockInitialValues({'cpuThreads': 9});
    final repository = SettingsRepository(SettingsService());

    repository.seed(const AppSettings(cpuThreads: 2));

    expect((await repository.load()).cpuThreads, 2);
    expect(repository.settings.cpuThreads, 2);
  });

  test('a listener that came late is told the next change, not the last', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SettingsRepository(SettingsService());
    await repository.save(const AppSettings(cpuThreads: 3));

    final heard = <int>[];
    final listening = repository.changes.listen((value) => heard.add(value.cpuThreads));
    addTearDown(listening.cancel);

    // What holds already is read off `settings`; the stream is for what
    // happens next.
    expect(heard, isEmpty);
    expect(repository.settings.cpuThreads, 3);

    await repository.save(const AppSettings(cpuThreads: 4));

    expect(heard, [4]);
  });

  test('writes a drag as its first tick and its last, one write at a time', () async {
    // A slider asks for a write on every tick, and each write rewrote the
    // whole preferences file on the interface's isolate.
    final disk = _HeldDisk();
    final settings = SettingsRepository(disk);

    final first = settings.save(const AppSettings(ttsSpeed: 1.1));
    final middle = settings.save(const AppSettings(ttsSpeed: 1.2));
    final last = settings.save(const AppSettings(ttsSpeed: 1.3));
    await pumpEventQueue();

    expect(disk.writes.map((value) => value.ttsSpeed), [1.1], reason: 'one write under way');
    expect(settings.settings.ttsSpeed, 1.3, reason: 'while every tick is on screen at once');

    disk.release();
    await pumpEventQueue();
    expect(disk.writes.map((value) => value.ttsSpeed), [1.1, 1.3], reason: 'the middle is passed');

    disk.release();
    await Future.wait([first, middle, last]);
    expect(identical(first, last), isTrue, reason: 'every tick waits for the same writes');
  });

  test('a write after the disk is free starts one of its own', () async {
    final disk = _HeldDisk();
    final settings = SettingsRepository(disk);

    final once = settings.save(const AppSettings(ttsSpeed: 1.1));
    disk.release();
    await once;
    final again = settings.save(const AppSettings(ttsSpeed: 1.2));
    disk.release();
    await again;

    expect(disk.writes.map((value) => value.ttsSpeed), [1.1, 1.2]);
  });
}

/// A disk that holds every write until the test lets it go.
class _HeldDisk extends Fake implements SettingsService {
  final writes = <AppSettings>[];
  final _held = <Completer<void>>[];

  void release() => _held.removeAt(0).complete();

  @override
  Future<void> save(AppSettings settings) {
    writes.add(settings);
    final held = Completer<void>();
    _held.add(held);
    return held.future;
  }
}
