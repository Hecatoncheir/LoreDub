// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../domain/character.dart';
import '../../domain/failure.dart';
import '../../domain/json_text.dart';

typedef CharacterRootProvider = Future<Directory> Function();

/// The characters the player recorded, in one file for every game.
///
/// The voices a session founds by itself stay per game — one game's cast
/// does not answer for another's — but a character the player recorded and
/// named is theirs, and the worker is handed this file whichever game runs.
class CharacterService {
  CharacterService({CharacterRootProvider? root}) : _root = root ?? getApplicationSupportDirectory;

  final CharacterRootProvider _root;

  /// Where the list is kept, made so the worker can read it.
  Future<String> file() async {
    final root = await _root();
    await root.create(recursive: true);
    return path.join(root.path, 'characters.json');
  }

  /// Where the recorded clips are kept: one per card, named by its id, so
  /// a card deleted takes its own clip and nobody else's.
  Future<Directory> _clips() async {
    final root = await _root();
    final clips = Directory(path.join(root.path, 'characters'));
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
  Future<CharacterLibrary> load() async {
    final source = File(await file());
    if (!await source.exists()) return CharacterLibrary.empty;
    try {
      return CharacterLibrary.fromJson(decodeJsonText(await source.readAsString()));
    } on FormatException {
      return CharacterLibrary.empty;
    } on FileSystemException {
      return CharacterLibrary.empty;
    }
  }

  /// Writes the library whole. Replaced in one step, so a crash mid-write
  /// leaves the characters as they were.
  Future<void> save(CharacterLibrary library) async {
    final destination = await file();
    final temporary = File('$destination.tmp');
    try {
      await temporary.writeAsString(jsonEncode(library.toJson()), flush: true);
      await temporary.rename(destination);
    } on FileSystemException catch (error) {
      throw LoreDubFailure(FailureCode.charactersSaveFailed, detail: error.message);
    }
  }

  /// Writes [library] where the player asked, as an import reads back. One
  /// card, the whole cast and a pack with its members are the same file with
  /// different contents.
  Future<void> exportTo(String destination, CharacterLibrary library) async {
    try {
      await File(destination).writeAsString(jsonEncode(library.toJson()), flush: true);
    } on FileSystemException catch (error) {
      throw LoreDubFailure(FailureCode.charactersExportFailed, detail: error.message);
    }
  }

  /// What the files the player chose hold. A file with no characters in it —
  /// the wrong file, or a damaged one — is reported rather than passed over
  /// in silence.
  Future<CharacterLibrary> readFiles(List<String> sources) async {
    final characters = <Character>[];
    final packs = <CharacterPack>[];
    for (final source in sources) {
      try {
        final read = decodeJsonText(await File(source).readAsString());
        final incoming = charactersFromJson(read);
        if (incoming.isEmpty) {
          throw LoreDubFailure(
            FailureCode.charactersImportFailed,
            detail: path.basename(source),
          );
        }
        characters.addAll(incoming);
        packs.addAll(packsFromJson(read));
      } on FormatException {
        throw LoreDubFailure(FailureCode.charactersImportFailed, detail: path.basename(source));
      } on FileSystemException {
        throw LoreDubFailure(FailureCode.charactersImportFailed, detail: path.basename(source));
      }
    }
    return CharacterLibrary(characters: characters, packs: packs);
  }
}
