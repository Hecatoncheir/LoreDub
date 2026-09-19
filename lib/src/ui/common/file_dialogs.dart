// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:file_selector/file_selector.dart';

/// The one way the screens ask the player for a file: every file LoreDub
/// hands on or reads back -- a cast, a glossary, a scheme -- is JSON, so a
/// save and an open look the same wherever they are asked for.
///
/// Provided above the dashboard (`LoreDubBootstrap`) and read off the context
/// before the first await, so a test can put one of its own in its place.
class FileDialogs {
  const FileDialogs();

  static const _json = [
    XTypeGroup(label: 'LoreDub', extensions: ['json']),
  ];

  /// The files the player chose to read, none when the dialog was closed.
  Future<List<String>> openJson() async => [
    for (final file in await openFiles(acceptedTypeGroups: _json)) file.path,
  ];

  /// Where the player chose to write, or null when the dialog was closed.
  Future<String?> saveJson(String suggestedName) async =>
      (await getSaveLocation(suggestedName: suggestedName, acceptedTypeGroups: _json))?.path;
}
