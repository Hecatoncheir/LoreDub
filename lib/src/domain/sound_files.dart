// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// What a card takes when files are dropped on it. Windows decodes them, so
/// the list is what it can play rather than what this app can read.
const soundFileExtensions = {
  '.wav',
  '.ogg',
  '.oga',
  '.opus',
  '.mp3',
  '.m4a',
  '.aac',
  '.flac',
  '.wma',
  '.webm',
  '.mp4',
};

/// The paths among [paths] that look like sound. A folder dropped by mistake,
/// or a screenshot, is left rather than sent to be decoded.
List<String> soundAmong(Iterable<String> paths) => [
  for (final path in paths)
    if (soundFileExtensions.contains(_extensionOf(path))) path,
];

String _extensionOf(String path) {
  final dot = path.lastIndexOf('.');
  return dot < 0 ? '' : path.substring(dot).toLowerCase();
}
