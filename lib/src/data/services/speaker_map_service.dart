// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../domain/failure.dart';
import '../../domain/json_text.dart';
import '../../domain/speaker_map.dart';
import 'voice_bank_service.dart';

typedef SpeakerMapRootProvider = Future<Directory> Function();

/// Whose voice reads whom, one file per game.
///
/// Unlike the bank beside it, this file is the interface's: the player makes
/// these replacements by hand, so nothing but this side ever writes them.
/// The worker is handed the path and reads it at start, and a replacement
/// made while a session runs is sent to it as well, so it takes effect on
/// the next line rather than on the next launch.
class SpeakerMapService {
  SpeakerMapService({SpeakerMapRootProvider? root}) : _root = root ?? _defaultRoot;

  final SpeakerMapRootProvider _root;

  static Future<Directory> _defaultRoot() async {
    final support = await getApplicationSupportDirectory();
    return Directory(path.join(support.path, 'speaker_map'));
  }

  /// The file of [game], with its directory made so the worker can read it.
  /// Named the way the bank is, so a game answers to one name throughout.
  Future<String> fileFor(String game) async {
    final root = await _root();
    await root.create(recursive: true);
    return path.join(root.path, voiceBankFileName(game));
  }

  /// What [game] replaces, or none when the file is missing or damaged.
  Future<Map<String, String>> load(String game) async {
    final source = File(await fileFor(game));
    if (!await source.exists()) return const {};
    try {
      return speakerMapFromJson(decodeJsonText(await source.readAsString()));
    } on FormatException {
      return const {};
    } on FileSystemException {
      return const {};
    }
  }

  /// Writes the replacements whole, in one step, so a crash mid-write leaves
  /// the game reading what it read before.
  Future<void> save(String game, Map<String, String> replacements) async {
    final destination = await fileFor(game);
    final temporary = File('$destination.tmp');
    try {
      await temporary.writeAsString(jsonEncode(speakerMapToJson(replacements)), flush: true);
      await temporary.rename(destination);
    } on FileSystemException catch (error) {
      throw LoreDubFailure(FailureCode.speakerMapSaveFailed, detail: error.message);
    }
  }
}
