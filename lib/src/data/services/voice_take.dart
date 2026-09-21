// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

/// Holds the capture's take open or lets it go (`ld_hold_take`), answering
/// with how much a take let go of had gathered.
typedef TakeHolder = int Function(int hold);

/// The take a character's card is recorded from, on the characters screen.
///
/// The capture holds it open meanwhile: neither a pause in the speech nor
/// the length of a phrase ends it, so what the card is measured from is
/// everything the player heard between pressing record and pressing stop.
/// What was measured while it ran is kept, so the screen can put the clip
/// that earned the card beside it; what is heard between takes belongs to
/// nobody.
class VoiceTake {
  VoiceTake({required this._hold, required this._discard});

  final TakeHolder _hold;
  final Future<void> Function(String path) _discard;

  /// How long closing a take waits for its recording to be measured: the
  /// capture's own wake-up, the file, and the converter reading three
  /// minutes of it on a busy CPU.
  static const measuring = Duration(seconds: 90);

  bool _recording = false;

  /// The clips measured while the take ran, kept until the next one.
  final _clips = <String>[];

  /// Waiting for the recording a closed take leaves behind, if anything is.
  Completer<void>? _closing;

  /// Whether a card is recording right now.
  bool get recording => _recording;

  /// Opens a take. What the previous one kept is let go of: the screen has
  /// had its chance to copy the clip that earned the card.
  void open() {
    _dropClips();
    _recording = true;
    _hold(1);
  }

  /// Closes the take and waits for what it recorded to be measured -- it is
  /// the only recording the take has, and the card is nothing without it.
  /// A take that gathered nothing, the game being silent throughout, has
  /// nothing to wait for.
  Future<void> close() async {
    if (!_recording) return;
    if (_hold(0) <= 0) {
      _recording = false;
      return;
    }
    final closing = Completer<void>();
    _closing = closing;
    try {
      await closing.future.timeout(measuring);
    } on TimeoutException {
      // Nothing came of it after all: what was gathered held no voice.
    } finally {
      if (identical(_closing, closing)) _closing = null;
      _recording = false;
    }
  }

  /// Keeps [clip], measured while the take runs, and says whether it did.
  /// One measured between takes is the caller's to throw away.
  bool keep(String clip) {
    if (!_recording) return false;
    _clips.add(clip);
    return true;
  }

  /// A recording has been measured: whoever waits for the take to close
  /// has what it heard.
  void measured() => _completeClosing();

  /// Lets the take go with the session it belongs to, and everything it
  /// kept.
  void abandon() {
    if (_recording) {
      _hold(0);
      _completeClosing();
    }
    _recording = false;
    _dropClips();
  }

  /// A new session starts with no take open.
  void reset() => _recording = false;

  void _completeClosing() {
    final closing = _closing;
    if (closing != null && !closing.isCompleted) closing.complete();
  }

  void _dropClips() {
    for (final clip in _clips) {
      unawaited(_discard(clip));
    }
    _clips.clear();
  }
}
