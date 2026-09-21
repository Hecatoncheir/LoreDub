// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/glossary.dart';
import '../services/glossary_catalog.dart';
import '../services/glossary_service.dart';
import '../services/native_engine_service.dart';
import 'settings_repository.dart';

/// What the player wrote down about their games. Theirs rather than one
/// game's, so every session that translates is handed the same file.
class GlossaryRepository {
  GlossaryRepository(this._settings, this._engine, [GlossaryService? service])
    : _service = service ?? GlossaryService();

  final SettingsRepository _settings;
  final NativeEngineService _engine;
  final GlossaryService _service;

  /// What is written down, with the packs LoreDub brings laid over it the
  /// first time the screen is opened.
  ///
  /// Only where the dubbing is into the language they are written in. A
  /// player dubbing into German is not offered a hundred Russian readings,
  /// and is offered them if they ever switch: nothing is marked as offered
  /// until it actually has been.
  Future<Glossary> load() async {
    final kept = await _service.load();
    // The settings themselves rather than the file they came from: one
    // owner, one read. Awaited rather than read off the field, so this
    // does not depend on having been started after whoever loads them.
    final settings = await _settings.load();
    if (settings.targetLanguage != builtInGlossaryLanguage) return kept;
    // Kept by the service before it is marked as offered.
    return _service.withBuiltIn(kept, builtInGlossary());
  }

  /// Keeps it, and tells a session already running: the player writes an
  /// entry because they just heard the line, and mean the next one to be
  /// said their way rather than the next session.
  Future<void> save(Glossary glossary) async {
    await _service.save(glossary);
    // What the active packs leave in use, not the whole shelf: the worker
    // applies what it is given and knows nothing of packs.
    await _engine.writeGlossary(glossary.inUse);
  }

  /// Writes the glossary where the player asked.
  Future<void> exportTo(String destination, Glossary glossary) =>
      _service.exportTo(destination, glossary);

  /// What the files the player chose hold, for the screen to merge into what
  /// is already written down.
  Future<Glossary> readFiles(List<String> sources) => _service.readFiles(sources);
}
