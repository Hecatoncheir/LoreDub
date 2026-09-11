// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

final _space = RegExp(r'\s+');
final _notWordCharacter = RegExp(r'[^\p{L}\p{N}]', unicode: true);

/// What is new in [current], the text subtitle mode just read, after
/// [previous], the text it read before; null when nothing is.
///
/// Games often grow a line in place — a dialogue box printing on, a second
/// sentence joining the first — and OCR then hands over the whole box again.
/// When at least half of [previous] opens [current] word for word, only the
/// words from the point where the two part are new; otherwise [current] is a
/// different line and all of it is. Text that matches [previous] throughout
/// has nothing new. Words are compared without case or punctuation, which
/// OCR reads differently from one scan to the next, and a dash or a quote
/// standing on its own is not counted as a word at all.
String? freshOcrText(String? previous, String current) {
  final words = _words(current);
  if (!words.any(_isWord)) return null;
  final before = [
    for (final word in previous == null ? const <String>[] : _words(previous))
      if (_isWord(word)) _comparable(word),
  ];
  if (before.isEmpty) return words.join(' ');
  var shared = 0;
  var index = 0;
  while (index < words.length && shared < before.length) {
    final word = _comparable(words[index]);
    if (word.isNotEmpty) {
      if (word != before[shared]) break;
      shared++;
    }
    index++;
  }
  if (shared * 2 < before.length) return words.join(' ');
  final rest = words.sublist(index);
  return rest.any(_isWord) ? rest.join(' ') : null;
}

List<String> _words(String text) => text.split(_space).where((word) => word.isNotEmpty).toList();

String _comparable(String word) => word.toLowerCase().replaceAll(_notWordCharacter, '');

bool _isWord(String word) => _comparable(word).isNotEmpty;
