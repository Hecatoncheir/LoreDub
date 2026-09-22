// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/hotkey.dart';

/// A key the player is told to press, marked in an interface string the way
/// HTML marks one: `<kbd>Esc</kbd>`, or `<kbd>{hotkey}</kbd>` around a
/// combination the settings hold, which [Hotkey.display] writes with
/// [Hotkey.joiner] between its keys. The strings are this application's own,
/// so nothing else puts the tag in them.
final _marked = RegExp('<kbd>(.*?)</kbd>');

/// One stretch of an interface string: [words] said as they are, or -- with
/// [keys] not empty -- keys pressed together.
typedef KeyedRun = ({String words, List<String> keys});

/// [text] cut into what is said and what is pressed, in the order they come.
List<KeyedRun> keyedRuns(String text) {
  final runs = <KeyedRun>[];
  var said = 0;
  for (final match in _marked.allMatches(text)) {
    if (match.start > said) runs.add((words: text.substring(said, match.start), keys: const []));
    final keys = [
      for (final key in match[1]!.split(Hotkey.joiner))
        if (key.trim().isNotEmpty) key.trim(),
    ];
    if (keys.isNotEmpty) runs.add((words: '', keys: keys));
    said = match.end;
  }
  if (said < text.length) runs.add((words: text.substring(said), keys: const []));
  return runs;
}
