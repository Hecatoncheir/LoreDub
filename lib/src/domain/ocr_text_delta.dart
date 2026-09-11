// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math';

final _space = RegExp(r'\s+');
final _notWordCharacter = RegExp(r'[^\p{L}\p{N}]', unicode: true);

/// What is new in [current], the text subtitle mode just read, after
/// [previous], the text it read before; null when nothing is.
///
/// Games often grow a line in place — a dialogue box printing on, a line
/// joining the ones above — and OCR then hands over the whole box again. The
/// two texts are compared whole, word by word: when most of the words of
/// [previous] turn up again in [current], in order, only the words that
/// appeared around them are new; otherwise [current] is a different line and
/// all of it is. A word read one way before and another way now counts as
/// the same word misread, not as a new one. Words are compared without case
/// or punctuation, which OCR reads differently from one scan to the next,
/// and a dash or a quote standing on its own is not counted as a word.
String? freshOcrText(String? previous, String current) {
  final tokens = _words(current);
  if (!tokens.any(_isWord)) return null;
  final before = [
    for (final word in previous == null ? const <String>[] : _words(previous))
      if (_isWord(word)) _comparable(word),
  ];
  if (before.isEmpty) return tokens.join(' ');
  // Where each word of [current] sits among the tokens, punctuation aside.
  final positions = [
    for (var index = 0; index < tokens.length; index++)
      if (_isWord(tokens[index])) index,
  ];
  final now = [for (final position in positions) _comparable(tokens[position])];

  // The longest run of words both texts share in order, counted from the
  // end so the walk below can read it forwards.
  final rows = before.length;
  final columns = now.length;
  final common = List.generate(rows + 1, (_) => List.filled(columns + 1, 0));
  for (var i = rows - 1; i >= 0; i--) {
    for (var j = columns - 1; j >= 0; j--) {
      common[i][j] = before[i] == now[j]
          ? common[i + 1][j + 1] + 1
          : max(common[i + 1][j], common[i][j + 1]);
    }
  }
  if (common[0][0] * 2 <= rows) return tokens.join(' ');

  // The words of [current] with no counterpart, gathered gap by gap. A gap
  // no longer than the words it stands in for is those words misread.
  final fresh = <int>[];
  final gap = <int>[];
  var replaced = 0;
  void closeGap() {
    if (gap.length > replaced) fresh.addAll(gap);
    gap.clear();
    replaced = 0;
  }

  var i = 0;
  var j = 0;
  while (i < rows || j < columns) {
    if (i < rows && j < columns && before[i] == now[j]) {
      closeGap();
      i++;
      j++;
    } else if (j < columns && (i == rows || common[i][j + 1] >= common[i + 1][j])) {
      gap.add(j);
      j++;
    } else {
      replaced++;
      i++;
    }
  }
  closeGap();
  if (fresh.isEmpty) return null;

  // Each run of new words as it was read, with the punctuation inside it.
  final runs = <String>[];
  var start = 0;
  for (var index = 1; index <= fresh.length; index++) {
    if (index < fresh.length && fresh[index] == fresh[index - 1] + 1) continue;
    final first = positions[fresh[start]];
    final last = positions[fresh[index - 1]];
    runs.add(tokens.sublist(first, last + 1).join(' '));
    start = index;
  }
  return runs.join(' ');
}

List<String> _words(String text) => text.split(_space).where((word) => word.isNotEmpty).toList();

String _comparable(String word) => word.toLowerCase().replaceAll(_notWordCharacter, '');

bool _isWord(String word) => _comparable(word).isNotEmpty;
