// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// How fast a line is read when others are already waiting to be heard.
library;

/// Lines waiting for the voice before the dubbing starts hurrying.
///
/// One or two are the ordinary back-and-forth of a scene: a character
/// answering before the last one has finished is what the overlap is for.
/// Past that the queue is time the player spends further behind the game.
const patientLines = 2;

/// What each line beyond [patientLines] adds to the pace.
const hurryStep = 0.1;

/// The most the dubbing hurries, as a share of the pace the player chose.
/// Read faster than this a phrase is heard but no longer followed.
const hurryLimit = 1.5;

/// The pace [chosen] becomes with [waiting] lines queued for the voice.
///
/// The speech model has no rate control of its own — the worker retimes the
/// waveform — so this is a number handed to it per line rather than a
/// setting of the session. It is deliberately blind to the recognition
/// queue: reading faster empties the queue of lines waiting to be spoken,
/// while lines waiting to be recognized are not held up by the voice at all,
/// and hurrying for them would only rush a dubbing that is late anyway.
double hurriedSpeed(double chosen, int waiting) {
  if (waiting <= patientLines) return chosen;
  final hurry = 1 + hurryStep * (waiting - patientLines);
  return (chosen * (hurry < hurryLimit ? hurry : hurryLimit)).clamp(0.5, 2.0);
}
