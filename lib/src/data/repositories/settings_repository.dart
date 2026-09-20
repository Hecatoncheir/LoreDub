// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import '../../domain/app_settings.dart';
import '../services/settings_service.dart';

/// What the player configured, and who to tell when it changes.
///
/// Everything in the application reads these: the pipeline for what to
/// dub and how far to turn the game down, the shell for the language a
/// toast is worded in and the proxy an update check goes through, the
/// canvas for what it draws. They used to be read off `SettingsCubit`,
/// which meant every part that needed them had to be handed that cubit or
/// a closure over it, and every part that had to follow a change had to be
/// wired to it by whatever built them both.
///
/// So the settings live here, with a stream beside them. [settings] is what
/// they are now, for the answer a caller needs at once; [changes] is for
/// the parts that have to follow. A late listener gets the current value
/// first, so nothing has to be told twice or ask before subscribing.
class SettingsRepository {
  SettingsRepository(this._service);

  final SettingsService _service;

  /// Synchronous on purpose. A screen that writes here also listens here,
  /// and with the usual asynchronous delivery its own echo arrived a
  /// microtask later -- after it had already moved on -- and put the older
  /// value back. Delivered as it is published, the order is the
  /// repository's and a caller that awaited a write sees it done.
  final _changes = StreamController<AppSettings>.broadcast(sync: true);
  AppSettings _settings = const AppSettings();

  /// What the settings are now. The default set until [load] has run: the
  /// application draws before it has read the disk.
  AppSettings get settings => _settings;

  /// Every value from now on. What holds at this moment is [settings], and
  /// a listener that needs it has it there: the stream does not replay.
  ///
  /// It could -- a generator yielding the current value first reads well --
  /// but cancelling a subscription to one never completes inside a widget
  /// test's zone, and every teardown that closed a cubit hung on it. A
  /// listener misses nothing either way: the load publishes, so whoever
  /// subscribed while the defaults stood is told the moment the disk is
  /// read.
  Stream<AppSettings> get changes => _changes.stream;

  /// Reads what was stored, once.
  ///
  /// Whoever needs the settings before doing their own work awaits this
  /// rather than relying on being started after whoever else reads them.
  /// The glossary does: which built-in packs it is offered depends on the
  /// dubbing language, so loaded beside the settings the two raced. Asked
  /// again, it answers with the read already in flight or already done —
  /// the file is read once whoever asks first.

  /// Publishes [value] at once and writes it behind that: what the player
  /// just did should be on screen before the disk has heard about it.
  Future<void> save(AppSettings value) async {
    _publish(value);
    await _service.save(value);
  }

  /// Publishes [value] as though it had been read, without writing it.
  ///
  /// What `SettingsCubit.seed` stages through, so a test arranging the
  /// settings a screen is drawn from arranges them where everything reads
  /// them rather than in one cubit's own state. Staged settings count as
  /// read: nothing goes to the disk afterwards and puts them back.
  void seed(AppSettings value) {
    _publish(value);
    _loading = Future.value(value);
  }

  Future<AppSettings>? _loading;

  Future<AppSettings> load() => _loading ??= _read();

  Future<AppSettings> _read() async {
    _publish(await _service.load());
    return _settings;
  }

  void _publish(AppSettings value) {
    _settings = value;
    if (!_changes.isClosed) _changes.add(value);
  }

  Future<void> dispose() => _changes.close();
}
