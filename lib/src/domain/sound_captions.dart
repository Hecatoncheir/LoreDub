// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// The captions a recognizer writes for what it hears but nobody says —
/// "(soft music)", "[Music]", "*laughs*", "♪ la la ♪" — and that subtitles
/// often carry too. Whisper learned them from subtitles, so a stretch of
/// music or noise comes back as one of these rather than as silence;
/// `-sns` keeps most of them out, not all.
final _caption = RegExp(r'\([^()]*\)|\[[^\[\]]*\]|\*[^*]*\*|♪[^♪]*♪|[♪♫]');

/// A caption the edge of a captured segment cut in half: "(soft music" with
/// nothing closing it, or "music playing)" with nothing opening it. Only what
/// is left once the whole captions are out can be one of these, or the halves
/// would take the speech between two captions with them.
final _captionOpened = RegExp(r'[(\[][^(\[]*$');
final _captionClosed = RegExp(r'^[^)\]]*[)\]]');

final _space = RegExp(r'\s+');
final _wordCharacter = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// [text] without its sound captions; empty when nothing spoken is left, so
/// a line of pure music is neither translated nor voiced.
String withoutSoundCaptions(String text) {
  final spoken = text
      .replaceAll(_caption, ' ')
      .replaceAll(_captionOpened, ' ')
      .replaceAll(_captionClosed, ' ')
      .replaceAll(_space, ' ')
      .trim();
  return _wordCharacter.hasMatch(spoken) ? spoken : '';
}
