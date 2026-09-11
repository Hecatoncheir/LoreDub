// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../domain/failure.dart';

typedef VoiceBankRootProvider = Future<Directory> Function();

/// The file name a game's voices are kept under: its executable, lower-cased
/// and stripped to what every file system accepts. Without a game — system
/// audio with nothing chosen — the voices share one bank of their own.
String voiceBankFileName(String game) {
  final stem = path
      .basenameWithoutExtension(game.trim())
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9._-]+'), '_')
      .replaceAll(RegExp(r'^[._]+'), '');
  return '${stem.isEmpty ? 'system' : stem}.json';
}

/// Where the original voice keeps the fingerprints of the characters it has
/// met, one file per game.
///
/// The worker is the one that fills a bank, since only it can compute a
/// fingerprint; this side names the file, counts what is there and deletes
/// it. A file is `{"version": 1, "voices": [[256 numbers], ...]}`.
class VoiceBankService {
  VoiceBankService({VoiceBankRootProvider? root}) : _root = root ?? _defaultRoot;

  final VoiceBankRootProvider _root;

  static Future<Directory> _defaultRoot() async {
    final support = await getApplicationSupportDirectory();
    return Directory(path.join(support.path, 'voice_bank'));
  }

  /// The bank of [game], with its directory made so the worker can write it.
  Future<String> fileFor(String game) async {
    final root = await _root();
    await root.create(recursive: true);
    return path.join(root.path, voiceBankFileName(game));
  }

  /// How many voices all the games' banks hold together. A file that cannot
  /// be read counts as empty: the worker starts it afresh in the same way.
  Future<int> count() async {
    final root = await _root();
    if (!await root.exists()) return 0;
    var total = 0;
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! File || path.extension(entry.path) != '.json') continue;
      try {
        final json = jsonDecode(await entry.readAsString());
        if (json case {'voices': final List<Object?> voices}) total += voices.length;
      } on FormatException {
        continue;
      } on FileSystemException {
        continue;
      }
    }
    return total;
  }

  /// Forgets every voice of every game.
  Future<void> clear() async {
    final root = await _root();
    try {
      if (await root.exists()) await root.delete(recursive: true);
    } on FileSystemException catch (error) {
      throw LoreDubFailure(
        FailureCode.voiceBankClearFailed,
        detail: '${error.path}: ${error.message}',
      );
    }
  }
}
