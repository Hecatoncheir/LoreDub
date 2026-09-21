// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../../domain/failure.dart';
import '../../domain/glossary.dart';
import 'json_file_store.dart';

/// What the player has told the dubbing about their games, in one file.
///
/// Kept beside the cast rather than beside the voice bank: a bank is founded
/// by a session and belongs to the game it heard, while this is written by
/// hand and is the player's, whichever game runs.
class GlossaryService {
  GlossaryService({DirectoryProvider? root})
    : _store = JsonFileStore(
        fileName: 'glossary.json',
        decode: Glossary.fromJson,
        encode: (glossary) => glossary.toJson(),
        empty: Glossary.empty,
        saveFailure: FailureCode.glossarySaveFailed,
        root: root,
      );

  final JsonFileStore<Glossary> _store;

  /// Where it is kept, made so the worker can read it.
  Future<String> file() => _store.file();

  /// [glossary] with the built-in pack laid over it and kept, the first time
  /// only.
  ///
  /// Once only, because a pack the player threw away must not come back at
  /// the next start; the mark is a file beside the glossary rather than a
  /// setting, since it is about this glossary and is lost with it. It is
  /// written after the glossary it marks, so a save that fails leaves the
  /// pack to be offered again rather than marked as offered and lost. An
  /// entry the player has already written under the same source is left as
  /// theirs. The pack arrives switched off, like any other that arrives: it
  /// must not narrow what the dubbing reads without being asked to.
  Future<Glossary> withBuiltIn(Glossary glossary, Glossary builtIn) async {
    final mark = File(path.join((await _store.directory()).path, 'glossary.builtin'));
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
    await save(merged);
    try {
      await mark.writeAsString(
        'The built-in pack has been offered once. Delete this file to be offered it again.',
        flush: true,
      );
    } on FileSystemException {
      // A mark that cannot be written is a pack offered again next time,
      // which finds its entries already there and adds nothing twice.
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
    final destination = path.join((await _store.directory()).path, 'glossary.session.json');
    await File(destination).writeAsString(
      jsonEncode((await load()).inUse.toJson()),
      flush: true,
    );
    return destination;
  }

  /// Everything written down, or nothing when the file is missing or
  /// damaged — the screen then opens empty rather than refusing to open.
  Future<Glossary> load() => _store.load();

  Future<void> save(Glossary glossary) => _store.save(glossary);

  /// Writes [glossary] where the player asked, as an import reads back. The
  /// whole of it or one entry is the same file with different contents.
  Future<void> exportTo(String destination, Glossary glossary) =>
      exportJson(destination, glossary.toJson(), FailureCode.glossaryExportFailed);

  /// What the files the player chose hold, merged in the order they were
  /// named. A file with nothing in it -- the wrong file, or a damaged one --
  /// is reported rather than passed over in silence.
  Future<Glossary> readFiles(List<String> sources) async {
    var read = Glossary.empty;
    for (final incoming in await importJsonFiles(
      sources,
      decode: Glossary.fromJson,
      holdsNothing: (glossary) => glossary.isEmpty,
      failure: FailureCode.glossaryImportFailed,
    )) {
      for (final entry in incoming.entries) {
        read = read.keeping(entry);
      }
      for (final pack in incoming.packs) {
        read = read.keepingPack(pack);
      }
    }
    return read;
  }
}
