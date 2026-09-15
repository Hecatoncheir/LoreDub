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
