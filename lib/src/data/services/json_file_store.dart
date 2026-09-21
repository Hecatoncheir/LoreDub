// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../domain/failure.dart';
import '../../domain/json_text.dart';

/// Where the application keeps its files; a test hands over a directory of
/// its own.
typedef DirectoryProvider = Future<Directory> Function();

/// One value the application keeps as a JSON file of its own: the cast, the
/// glossary, the shelf of schemes, the canvas's arrangement.
///
/// Read as the empty value when the file is missing or damaged, so a screen opens
/// empty rather than refusing to open -- damaged meaning not JSON at all or
/// JSON of the wrong shape, which the value's `fromJson` finds out with a
/// cast. Written whole through a temporary file renamed into place, so a
/// crash mid-write leaves what was there, and one write at a time: the
/// canvas saves on every drop without waiting, and two writes through the
/// same temporary file renamed over each other.
class JsonFileStore<T> {
  JsonFileStore({
    required this.fileName,
    required this._decode,
    required this._encode,
    required this._empty,
    required this._saveFailure,
    DirectoryProvider? root,
  }) : _root = root ?? getApplicationSupportDirectory;

  final String fileName;
  final T Function(Object? json) _decode;
  final Object? Function(T value) _encode;
  final T _empty;
  final FailureCode _saveFailure;
  final DirectoryProvider _root;

  /// The write under way, which the next one waits for.
  Future<void> _writing = Future.value();

  /// The directory the file sits in, made if it was not there.
  Future<Directory> directory() async {
    final root = await _root();
    await root.create(recursive: true);
    return root;
  }

  /// Where the value is kept, so the worker can be handed the path.
  Future<String> file() async => path.join((await directory()).path, fileName);

  Future<T> load() async {
    try {
      final source = File(await file());
      if (!await source.exists()) return _empty;
      return _decode(decodeJsonText(await source.readAsString()));
    } on Object catch (error) {
      if (_isDamage(error)) return _empty;
      rethrow;
    }
  }

  /// Writes [value] once every write asked for before it has finished.
  Future<void> save(T value) {
    final write = _writing.then((_) => _write(value));
    // The next write waits for this one whether or not it failed; the
    // failure is the caller's, through the future returned.
    _writing = write.then((_) {}, onError: (Object _) {});
    return write;
  }

  Future<void> _write(T value) async {
    final destination = await file();
    final temporary = File('$destination.tmp');
    try {
      await temporary.writeAsString(jsonEncode(_encode(value)), flush: true);
      await temporary.rename(destination);
    } on FileSystemException catch (error) {
      throw LoreDubFailure(_saveFailure, detail: error.message);
    }
  }
}

/// Writes [json] to a file of the player's choosing.
Future<void> exportJson(String destination, Object? json, FailureCode failure) async {
  try {
    await File(destination).writeAsString(jsonEncode(json), flush: true);
  } on FileSystemException catch (error) {
    throw LoreDubFailure(failure, detail: error.message);
  }
}

/// What each of the files the player chose holds, in the order they were
/// named.
///
/// A file holding nothing -- the wrong file, or a damaged one -- is reported
/// by name as [failure] rather than passed over in silence, which is the
/// difference between this and [JsonFileStore.load]: one is the player
/// naming a file, the other the application opening its own.
Future<List<T>> importJsonFiles<T>(
  List<String> sources, {
  required T Function(Object? json) decode,
  required bool Function(T value) holdsNothing,
  required FailureCode failure,
}) async {
  final read = <T>[];
  for (final source in sources) {
    final refused = LoreDubFailure(failure, detail: path.basename(source));
    final T value;
    try {
      value = decode(decodeJsonText(await File(source).readAsString()));
    } on Object catch (error) {
      if (_isDamage(error)) throw refused;
      rethrow;
    }
    if (holdsNothing(value)) throw refused;
    read.add(value);
  }
  return read;
}

/// A file that could not be read, or read as something other than it
/// should: not JSON, or JSON whose shape a `fromJson` cast refused.
bool _isDamage(Object error) =>
    error is FormatException || error is FileSystemException || error is TypeError;
