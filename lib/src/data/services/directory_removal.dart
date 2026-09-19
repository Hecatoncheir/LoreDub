// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:flutter/foundation.dart';

/// Windows errors that mean something outside this application still holds
/// a file or the folder: a sharing violation, access denied, and a
/// directory whose files are only pending deletion.
const _heldOpen = {5, 32, 145};

/// Removes [directory] and everything in it, waiting out a hold on it.
///
/// On Windows an on-access virus scanner opens a file the moment it is
/// written or renamed -- an archive of a downloaded runtime always gets a
/// look -- and while it holds one, the folder cannot be removed. The hold
/// lasts milliseconds, so the removal is tried again rather than reported:
/// a player who asked for a package to go should not be told it could not
/// because something glanced at it. A handle the application leaked itself
/// outlasts every attempt and is reported as it always was.
///
/// A directory that is not there is nothing to do.
Future<void> deleteDirectory(
  Directory directory, {
  int attempts = 20,
  Duration wait = const Duration(milliseconds: 100),
  @visibleForTesting Future<void> Function(Directory directory)? remove,
}) async {
  final delete = remove ?? (target) => target.delete(recursive: true);
  for (var attempt = 1; ; attempt++) {
    try {
      if (await directory.exists()) await delete(directory);
      return;
    } on FileSystemException catch (error) {
      if (attempt >= attempts || !_heldOpen.contains(error.osError?.errorCode)) rethrow;
      await Future<void>.delayed(wait);
    }
  }
}
