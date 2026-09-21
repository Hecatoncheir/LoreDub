// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:path/path.dart' as path;

import '../../domain/character.dart';
import '../../domain/failure.dart';
import 'json_file_store.dart';

/// The characters the player recorded, in one file for every game.
///
/// The voices a session founds by itself stay per game — one game's cast
/// does not answer for another's — but a character the player recorded and
/// named is theirs, and the worker is handed this file whichever game runs.
class CharacterService {
  CharacterService({DirectoryProvider? root})
    : _store = JsonFileStore(
        fileName: 'characters.json',
        decode: CharacterLibrary.fromJson,
        encode: (library) => library.toJson(),
        empty: CharacterLibrary.empty,
        saveFailure: FailureCode.charactersSaveFailed,
        root: root,
      );

  final JsonFileStore<CharacterLibrary> _store;

  /// Where the list is kept, made so the worker can read it.
  Future<String> file() => _store.file();

  /// Where the recorded clips are kept: one per card, named by its id, so
  /// a card deleted takes its own clip and nobody else's.
  Future<Directory> _clips() async {
    final clips = Directory(path.join((await _store.directory()).path, 'characters'));
    await clips.create(recursive: true);
    return clips;
  }

  /// The clip recorded for [id], or null when the card has none. An import
  /// carries the fingerprint but no audio, so a card can be voiced and still
  /// have nothing to play.
  Future<String?> clipFor(String id) async {
    final clip = File(path.join((await _clips()).path, '$id.wav'));
    return await clip.exists() ? clip.path : null;
  }

  /// The cards that have a clip to play.
  Future<Set<String>> clips() async {
    final directory = await _clips();
    return {
      await for (final entry in directory.list(followLinks: false))
        if (entry is File && entry.path.endsWith('.wav')) path.basenameWithoutExtension(entry.path),
    };
  }

  /// Keeps [source] as the clip of [id], replacing whatever was there.
  Future<void> keepClip(String id, String source) async {
    final clip = File(path.join((await _clips()).path, '$id.wav'));
    try {
      await File(source).copy(clip.path);
    } on FileSystemException catch (error) {
      throw LoreDubFailure(FailureCode.charactersSaveFailed, detail: error.message);
    }
  }

  /// Drops the clip of [id], which a card that is being deleted no longer
  /// answers for.
  Future<void> removeClip(String id) async {
    try {
      final clip = File(path.join((await _clips()).path, '$id.wav'));
      if (await clip.exists()) await clip.delete();
    } on FileSystemException {
      // A clip left behind costs a few kilobytes and nothing else.
    }
  }

  /// Every character and pack the player has, or none when the file is
  /// missing or damaged — the screen then starts empty rather than refusing
  /// to open.
  Future<CharacterLibrary> load() => _store.load();

  Future<void> save(CharacterLibrary library) => _store.save(library);

  /// Writes [library] where the player asked, as an import reads back. One
  /// card, the whole cast and a pack with its members are the same file with
  /// different contents.
  Future<void> exportTo(String destination, CharacterLibrary library) =>
      exportJson(destination, library.toJson(), FailureCode.charactersExportFailed);

  /// What the files the player chose hold. A file with no characters in it —
  /// the wrong file, or a damaged one — is reported rather than passed over
  /// in silence. The packs are read unpruned: a pack in one file may name a
  /// card that arrives in another.
  Future<CharacterLibrary> readFiles(List<String> sources) async {
    final read = await importJsonFiles(
      sources,
      decode: (json) => (characters: charactersFromJson(json), packs: packsFromJson(json)),
      holdsNothing: (file) => file.characters.isEmpty,
      failure: FailureCode.charactersImportFailed,
    );
    return CharacterLibrary(
      characters: [for (final file in read) ...file.characters],
      packs: [for (final file in read) ...file.packs],
    );
  }
}
