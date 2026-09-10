// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:collection';

/// One captured phrase waiting to be recognized, translated and voiced.
class PendingPhrase {
  PendingPhrase.audio(String this.wavePath) : text = null;

  PendingPhrase.text(String this.text) : wavePath = null;

  /// Set for captured audio; the file is deleted once the phrase is handled.
  final String? wavePath;

  /// Set for text that OCR already recognized.
  final String? text;
}

/// Processes captured phrases one at a time, in the order they were spoken.
///
/// Recognition, translation and synthesis are serialized so a weak CPU is
/// never asked to run two inferences at once. Nothing is dropped: a phrase
/// that took long to dub still gets voiced. Keeping up with the game is a
/// matter of the pipeline being fast enough, not of discarding speech, so
/// playback deliberately happens outside this queue.
class PhraseQueue {
  PhraseQueue({required this.process});

  final Future<void> Function(PendingPhrase phrase) process;
  final _waiting = Queue<PendingPhrase>();
  Future<void>? _draining;

  int get length => _waiting.length;

  /// Completes when the queue has nothing left to process.
  Future<void> get drained => _draining ?? Future<void>.value();

  void add(PendingPhrase phrase) {
    _waiting.add(phrase);
    _draining ??= _drain();
  }

  /// Forgets everything still waiting. The phrase already being processed is
  /// not interrupted; its caller decides what to do with the result.
  List<PendingPhrase> clear() {
    final abandoned = _waiting.toList();
    _waiting.clear();
    return abandoned;
  }

  Future<void> _drain() async {
    try {
      while (_waiting.isNotEmpty) {
        try {
          await process(_waiting.removeFirst());
        } on Object {
          // Reporting is up to the processor; one bad phrase must not strand
          // the ones queued behind it.
        }
      }
    } finally {
      _draining = null;
    }
  }
}
