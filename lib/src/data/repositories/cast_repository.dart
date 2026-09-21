// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import '../../domain/character.dart';
import '../services/character_service.dart';
import '../services/native_engine_service.dart';

/// The cards the player recorded and named, and the packs they are filed
/// in: one file for every game, because the player owns these.
///
/// Two screens work on the same cast. The characters screen records and
/// names the cards; the canvas draws them and says who reads whom. The
/// canvas used to reach the cast through the characters *cubit* — reading
/// its state and calling its methods — so a screen's cubit was part of
/// another screen's machinery. Both read here instead.
///
/// The files that go with the cards are here as well: the clip each card
/// was measured from, and the files the cast is exported to and imported
/// from. A session is handed [file] and reads the cast itself.
class CastRepository {
  CastRepository(this._engine, [CharacterService? service])
    : _service = service ?? CharacterService();

  /// Told of a substitution while it runs, so the next line is read anew.
  final NativeEngineService _engine;
  final CharacterService _service;

  /// Synchronous on purpose. A screen that writes here also listens here,
  /// and with the usual asynchronous delivery its own echo arrived a
  /// microtask later -- after it had already moved on -- and put the older
  /// value back. Delivered as it is published, the order is the
  /// repository's and a caller that awaited a write sees it done.
  final _changes = StreamController<CharacterLibrary>.broadcast(sync: true);
  CharacterLibrary _library = CharacterLibrary.empty;

  /// The cast as it stands.
  List<Character> get cast => _library.characters;

  CharacterLibrary get library => _library;

  /// Every value from now on. What holds at this moment is [library]: the
  /// stream does not replay, for the reason `SettingsRepository.changes`
  /// gives.
  Stream<CharacterLibrary> get changes => _changes.stream;

  /// Reads the cards once, whoever asks first -- the characters screen
  /// for its list, the canvas before it draws them -- so neither depends on
  /// being started after the other.
  Future<CharacterLibrary> load() => _loading ??= _read();

  Future<CharacterLibrary>? _loading;

  Future<CharacterLibrary> _read() async {
    _publish(await _service.load());
    return _library;
  }

  /// Publishes [value] at once and writes it behind that, so a card the
  /// player just named is on screen before the disk has heard of it.
  Future<void> save(CharacterLibrary value) async {
    _publish(value);
    await _service.save(value);
  }

  /// Reads [id] in [target]'s voice wherever they are recognized, or in
  /// their own again when [target] is null.
  ///
  /// This is the standing choice the card carries into every game. A
  /// session already running holds the cast it started with, so it is told
  /// as well and the next line of this character is read anew.
  Future<void> voiceAs(String id, String? target) async {
    if (id == target) return;
    await save(
      CharacterLibrary(
        characters: [
          for (final character in cast)
            if (character.id == id)
              character.copyWith(voicedBy: target, clearVoicedBy: target == null)
            else
              character,
        ],
        packs: _library.packs,
      ),
    );
    await _engine.voiceCharacterAs(id, target);
  }

  /// The cards that are out of the mix, as the canvas now draws them: each
  /// of them lends its voice to nobody and is read as it is heard.
  ///
  /// Nothing of the cards changes — who stands in for whom waits in them —
  /// so there is nothing to write; only a session already running has to be
  /// told, or it would go on reading the cast until the next start.
  Future<void> readAsHeard(Set<String> value) => _engine.readAsHeard(value);

  /// Where the cast is kept, which every session is handed.
  Future<String> file() => _service.file();

  /// The clip recorded for a card, when it kept one. An imported card
  /// carries a fingerprint but no audio, so it may have none.
  Future<String?> clipFor(String id) => _service.clipFor(id);

  /// The cards with a clip to play.
  Future<Set<String>> clips() => _service.clips();

  Future<void> keepClip(String id, String source) => _service.keepClip(id, source);

  Future<void> removeClip(String id) => _service.removeClip(id);

  Future<void> exportTo(String destination, CharacterLibrary library) =>
      _service.exportTo(destination, library);

  /// What the files the player chose hold, for the screen to merge in.
  Future<CharacterLibrary> readFiles(List<String> sources) => _service.readFiles(sources);

  /// Stages [value] as though it had been read, without writing it.
  void seed(CharacterLibrary value) {
    _publish(value);
    // Staged cards count as read: nothing reads the disk afterwards and
    // puts others in their place.
    _loading = Future.value(value);
  }

  void _publish(CharacterLibrary value) {
    _library = value;
    if (!_changes.isClosed) _changes.add(value);
  }

  Future<void> dispose() => _changes.close();
}
