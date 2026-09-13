// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../domain/character.dart';
import '../../domain/failure.dart';

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

  /// Every character and pack the player has, or none when the file is
  /// missing or damaged — the screen then starts empty rather than refusing
  /// to open.
  Future<CharacterLibrary> load() async {
    final source = File(await file());
    if (!await source.exists()) return CharacterLibrary.empty;
    try {
      return CharacterLibrary.fromJson(jsonDecode(await source.readAsString()));
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
        final read = jsonDecode(await File(source).readAsString());
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
