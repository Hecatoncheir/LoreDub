// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../domain/failure.dart';
import '../../domain/glossary.dart';
import '../../domain/json_text.dart';

typedef GlossaryRootProvider = Future<Directory> Function();

/// What the player has told the dubbing about their games, in one file.
///
/// Kept beside the cast rather than beside the voice bank: a bank is founded
/// by a session and belongs to the game it heard, while this is written by
/// hand and is the player's, whichever game runs.
class GlossaryService {
  GlossaryService({GlossaryRootProvider? root}) : _root = root ?? getApplicationSupportDirectory;

  final GlossaryRootProvider _root;

  /// Where it is kept, made so the worker can read it.
  Future<String> file() async {
    final root = await _root();
    await root.create(recursive: true);
    return path.join(root.path, 'glossary.json');
  }

  /// [glossary] with the built-in pack laid over it, the first time only.
  ///
  /// Once only, because a pack the player threw away must not come back at
  /// the next start; the mark is a file beside the glossary rather than a
  /// setting, since it is about this glossary and is lost with it. An entry
  /// the player has already written under the same source is left as theirs.
  /// The pack arrives switched off, like any other that arrives: it must not
  /// narrow what the dubbing reads without being asked to.
  Future<Glossary> withBuiltIn(Glossary glossary, Glossary builtIn) async {
    final root = await _root();
    await root.create(recursive: true);
    final mark = File(path.join(root.path, 'glossary.builtin'));
    try {
      if (await mark.exists()) return glossary;
    } on FileSystemException {
      return glossary;
    }
    var merged = glossary;
    for (final entry in builtIn.entries) {
      if (merged.match(entry.kind, entry.source) == null) merged = merged.keeping(entry);
    }
    for (final pack in builtIn.packs) {
      if (merged.packWithId(pack.id) == null) merged = merged.keepingPack(pack);
    }
    try {
      await mark.writeAsString(
        'The built-in pack has been offered once. Delete this file to be offered it again.',
        flush: true,
      );
    } on FileSystemException {
      // A mark that cannot be written is a pack offered again next time,
      // which is a smaller wrong than refusing to open the screen.
      return glossary;
    }
    return merged;
  }

  /// The file a session is handed.
  ///
  /// Not [file]: that one holds the packs and everything in them, which is
  /// the question rather than the answer. Which entries are in use is
  /// [Glossary.inUse] and lives in one place, so the worker is given what it
  /// should apply and needs to know nothing about packs. Written afresh at
  /// every start; an edit made while a session runs reaches the worker
  /// through the request that saves it, not through this.
  Future<String> sessionFile() async {
    final root = await _root();
    await root.create(recursive: true);
    final destination = path.join(root.path, 'glossary.session.json');
    await File(destination).writeAsString(
      jsonEncode((await load()).inUse.toJson()),
      flush: true,
    );
    return destination;
  }

  /// Everything written down, or nothing when the file is missing or
  /// damaged — the screen then opens empty rather than refusing to open.
  Future<Glossary> load() async {
    final source = File(await file());
    if (!await source.exists()) return Glossary.empty;
    try {
      return Glossary.fromJson(decodeJsonText(await source.readAsString()));
    } on FormatException {
      return Glossary.empty;
    } on FileSystemException {
      return Glossary.empty;
    }
  }

  /// Writes [glossary] where the player asked, as an import reads back. The
  /// whole of it or one entry is the same file with different contents.
  Future<void> exportTo(String destination, Glossary glossary) async {
    try {
      await File(destination).writeAsString(jsonEncode(glossary.toJson()), flush: true);
    } on FileSystemException catch (error) {
      throw LoreDubFailure(FailureCode.glossaryExportFailed, detail: error.message);
    }
  }

  /// What the files the player chose hold, in the order they were named. A
  /// file with nothing in it -- the wrong file, or a damaged one -- is
  /// reported rather than passed over in silence, which is the difference
  /// between this and [load]: one is the player asking for a file, the other
  /// is the application opening its own.
  Future<Glossary> readFiles(List<String> sources) async {
    var read = Glossary.empty;
    for (final source in sources) {
      try {
        final incoming = Glossary.fromJson(decodeJsonText(await File(source).readAsString()));
        if (incoming.isEmpty) {
          throw LoreDubFailure(
            FailureCode.glossaryImportFailed,
            detail: path.basename(source),
          );
        }
        for (final entry in incoming.entries) {
          read = read.keeping(entry);
        }
        for (final pack in incoming.packs) {
          read = read.keepingPack(pack);
        }
      } on FormatException {
        throw LoreDubFailure(FailureCode.glossaryImportFailed, detail: path.basename(source));
      } on FileSystemException {
        throw LoreDubFailure(FailureCode.glossaryImportFailed, detail: path.basename(source));
      }
    }
    return read;
  }

  /// Writes it whole, renamed into place in one step so a crash mid-write
  /// leaves what was there before.
  Future<void> save(Glossary glossary) async {
    final destination = await file();
    final temporary = File('$destination.tmp');
    try {
      await temporary.writeAsString(jsonEncode(glossary.toJson()), flush: true);
      await temporary.rename(destination);
    } on FileSystemException catch (error) {
      throw LoreDubFailure(FailureCode.glossarySaveFailed, detail: error.message);
    }
  }
}
