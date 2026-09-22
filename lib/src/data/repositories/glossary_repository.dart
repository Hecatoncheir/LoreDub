// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import '../../domain/glossary.dart';
import '../../domain/pipeline_state.dart';
import '../services/glossary_catalog.dart';
import '../services/glossary_service.dart';
import '../services/native_engine_service.dart';
import 'settings_repository.dart';

/// What the player wrote down about their games. Theirs rather than one
/// game's, so every session that translates is handed the same file.
///
/// Two screens work on it. The glossary screen writes the entries and the
/// packs; the canvas draws the packs, switches them on and off -- on their
/// nodes, and as they are put in the line of text or taken out -- and says
/// which part of each it lets apply. Both read the glossary here and write it
/// here, so a pack switched on in one is switched on in the other.
class GlossaryRepository {
  GlossaryRepository(this._settings, this._engine, [GlossaryService? service])
    : _service = service ?? GlossaryService();

  final SettingsRepository _settings;
  final NativeEngineService _engine;
  final GlossaryService _service;

  /// Synchronous for the reason `CastRepository` gives: a screen that
  /// writes here listens here as well, and its own echo delivered a
  /// microtask later put the older glossary back.
  final _changes = StreamController<Glossary>.broadcast(sync: true);
  Glossary _glossary = Glossary.empty;

  /// What the canvas lets each pack it draws apply, as it last said.
  GlossaryReach _reach = const {};

  /// The glossary as it stands.
  Glossary get glossary => _glossary;

  /// Every value from now on. What holds at this moment is [glossary]: the
  /// stream does not replay, for the reason `SettingsRepository.changes`
  /// gives.
  Stream<Glossary> get changes => _changes.stream;

  /// What is written down, with the packs LoreDub brings laid over it the
  /// first time it is read -- whoever asks first, the glossary screen or the
  /// canvas, so neither depends on being started after the other.
  ///
  /// The packs only where the dubbing is into the language they are written
  /// in. A player dubbing into German is not offered a hundred Russian
  /// readings, and is offered them if they ever switch: nothing is marked as
  /// offered until it actually has been.
  Future<Glossary> load() => _loading ??= _read();

  Future<Glossary>? _loading;

  Future<Glossary> _read() async {
    final kept = await _service.load();
    // The settings themselves rather than the file they came from: one
    // owner, one read. Awaited rather than read off the field, so this
    // does not depend on having been started after whoever loads them.
    final settings = await _settings.load();
    final read = settings.targetLanguage == builtInGlossaryLanguage
        // Kept by the service before it is marked as offered.
        ? await _service.withBuiltIn(kept, builtInGlossary())
        : kept;
    _publish(read);
    return read;
  }

  /// Publishes [glossary] at once, keeps it, and tells a session already
  /// running: the player writes an entry because they just heard the line,
  /// and mean the next one to be said their way rather than the next
  /// session.
  ///
  /// A write that fails puts back what was there, rather than leave both
  /// screens showing what the file does not hold -- unless something newer
  /// has been published meanwhile, which is not this write's to undo.
  Future<void> save(Glossary glossary) async {
    final previous = _glossary;
    _publish(glossary);
    try {
      await _service.save(glossary);
    } catch (_) {
      if (identical(_glossary, glossary)) _publish(previous);
      rethrow;
    }
    await _tellSession();
  }

  /// What the canvas lets each pack it draws apply, told to a session
  /// already running when it changes what that session reads.
  ///
  /// Nothing is written: the scheme keeps the drawings with its own
  /// arrangement, which a session reads as it starts.
  Future<void> narrow(GlossaryReach reach) async {
    if (sameGlossaryReach(reach, _reach)) return;
    _reach = reach;
    await _tellSession();
  }

  /// What the worker is to apply, which is the packs switched on -- each
  /// narrowed to what the canvas lets it apply where the canvas draws the
  /// session. The screen's reading is not on the canvas and reads its packs
  /// whole, as it is started with them.
  Future<void> _tellSession() => _engine.writeGlossary(
    _glossary.inUseWithin(_engine.session == PipelineSession.screen ? const {} : _reach),
  );

  /// Writes the glossary where the player asked.
  Future<void> exportTo(String destination, Glossary glossary) =>
      _service.exportTo(destination, glossary);

  /// What the files the player chose hold, for the screen to merge into what
  /// is already written down.
  Future<Glossary> readFiles(List<String> sources) => _service.readFiles(sources);

  /// Stages [value] as though it had been read, without writing it.
  void seed(Glossary value) {
    _publish(value);
    // Staged entries count as read: nothing reads the disk afterwards and
    // puts others in their place.
    _loading = Future.value(value);
  }

  void _publish(Glossary value) {
    _glossary = value;
    if (!_changes.isClosed) _changes.add(value);
  }

  Future<void> dispose() => _changes.close();
}
