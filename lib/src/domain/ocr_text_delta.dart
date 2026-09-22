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

  final common = _lcsTable(before, now);
  if (common[0][0] * 2 <= before.length) return tokens.join(' ');

  // The words of [current] with no counterpart, gathered gap by gap. A gap
  // no longer than the words it stands in for is those words misread.
  final fresh = [
    for (final gap in _gaps(before, now, common))
      if (gap.words.length > gap.replaced) ...gap.words,
  ];
  if (fresh.isEmpty) return null;
  return _runs(tokens, positions, fresh).join(' ');
}

/// The length of the longest run of words [before] and [now] share in
/// order, from each pair of positions to the end: counted from the end so
/// the walk in [_gaps] can read it forwards.
List<List<int>> _lcsTable(List<String> before, List<String> now) {
  final common = List.generate(before.length + 1, (_) => List.filled(now.length + 1, 0));
  for (var i = before.length - 1; i >= 0; i--) {
    for (var j = now.length - 1; j >= 0; j--) {
      common[i][j] = before[i] == now[j]
          ? common[i + 1][j + 1] + 1
          : max(common[i + 1][j], common[i][j + 1]);
    }
  }
  return common;
}

/// Walks the two texts along the longest shared run and yields each stretch
/// between two shared words: the positions in [now] of the words that stand
/// there, and how many words of [before] they took the place of.
Iterable<({List<int> words, int replaced})> _gaps(
  List<String> before,
  List<String> now,
  List<List<int>> common,
) sync* {
  var words = <int>[];
  var replaced = 0;
  var i = 0;
  var j = 0;
  while (i < before.length || j < now.length) {
    if (i < before.length && j < now.length && before[i] == now[j]) {
      yield (words: words, replaced: replaced);
      words = [];
      replaced = 0;
      i++;
      j++;
    } else if (j < now.length && (i == before.length || common[i][j + 1] >= common[i + 1][j])) {
      words.add(j);
      j++;
    } else {
      replaced++;
      i++;
    }
  }
  yield (words: words, replaced: replaced);
}

/// Each run of consecutive [fresh] words as it was read, with the
/// punctuation inside it; [positions] places each word among [tokens].
List<String> _runs(List<String> tokens, List<int> positions, List<int> fresh) {
  final runs = <String>[];
  var start = 0;
  for (var index = 1; index <= fresh.length; index++) {
    if (index < fresh.length && fresh[index] == fresh[index - 1] + 1) continue;
    final first = positions[fresh[start]];
    final last = positions[fresh[index - 1]];
    runs.add(tokens.sublist(first, last + 1).join(' '));
    start = index;
  }
  return runs;
}

List<String> _words(String text) => text.split(_space).where((word) => word.isNotEmpty).toList();

String _comparable(String word) => word.toLowerCase().replaceAll(_notWordCharacter, '');

bool _isWord(String word) => _comparable(word).isNotEmpty;
