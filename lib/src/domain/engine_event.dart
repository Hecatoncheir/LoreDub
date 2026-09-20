// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'compute_device.dart';
import 'hotkey.dart';
import 'ocr_region.dart';
import 'pipeline_state.dart';

/// Everything the engine has to say, as a type rather than as a map.
///
/// It crosses from the native side and from the worker as JSON, and it used
/// to be read as JSON the whole way up: a screen asked `event['type']`,
/// then `event['seconds'] as num?` with a fallback for the case the key was
/// not there. Nothing checked that the key existed, that it was spelled the
/// same at both ends, or that a screen had answered every kind. The shapes
/// are written down here instead, and `NativeEngineService` builds them
/// once, at the boundary where the JSON arrives.
///
/// Sealed, so a `switch` over one is exhaustive and the analyzer names a
/// kind nobody answered.
sealed class EngineEvent {
  const EngineEvent();
}

/// The engine has started, come up, or come to rest.
///
/// [session] says whose it is. The engine serves one screen at a time and
/// the same stream reaches them all, so a screen that read another's start
/// as its own showed a session it could not stop. A state carrying no
/// session is `ld_stop` coming to rest, which ends whatever any screen was
/// showing.
class SessionStateChanged extends EngineEvent {
  const SessionStateChanged({required this.status, this.session});

  final PipelineStatus status;
  final PipelineSession? session;

  /// Whether a screen showing [mine] should follow this: its own session,
  /// or the engine coming to rest, which is everyone's.
  bool concerns(PipelineSession mine) => session == null || session == mine;
}

/// How far the worker is through its minutes of loading, and what it is
/// doing. A null [value] is the progress going away rather than reaching
/// zero.
class StartupProgressed extends EngineEvent {
  const StartupProgressed({this.value, this.stage = '', this.session});

  final double? value;
  final String stage;
  final PipelineSession? session;
}

/// One line, dubbed. [snapshot] is a line the player asked for by hand
/// rather than one the capture brought in, and it is kept in a list of its
/// own.
class LineDubbed extends EngineEvent {
  const LineDubbed({required this.line, this.snapshot = false});

  final TranscriptEntry line;
  final bool snapshot;
}

/// A voice placed while the scene session listens: no words, only who spoke
/// and for how long.
class SceneVoiceHeard extends EngineEvent {
  const SceneVoiceHeard({required this.speaker, required this.seconds});

  final String? speaker;
  final double seconds;
}

/// What was measured from the take a card is recording.
class CharacterVoiceMeasured extends EngineEvent {
  const CharacterVoiceMeasured({
    required this.vector,
    required this.seconds,
    this.gender,
    this.clip,
  });

  final List<double> vector;
  final double seconds;
  final String? gender;

  /// The recording itself, kept so the player can hear back what they
  /// caught. Absent where it was not worth keeping.
  final String? clip;
}

/// The snapshot key was pressed and the screen is being read.
class SnapshotReading extends EngineEvent {
  const SnapshotReading();
}

/// What the selection was read as. An empty [text] is nothing found, and
/// [failed] says the recognizer could not run at all rather than that the
/// rectangle held no words.
class SnapshotRead extends EngineEvent {
  const SnapshotRead({required this.text, this.failed = false});

  final String text;
  final bool failed;
}

/// The player redrew the subtitle frame over the running game. A null
/// [region] is a selection that missed the window.
class SubtitleFrameMoved extends EngineEvent {
  const SubtitleFrameMoved(this.region);

  final OcrRegion? region;
}

/// The language whisper settled on, or null once it no longer has one.
class LanguageDetected extends EngineEvent {
  const LanguageDetected(this.code);

  final String? code;
}

/// The voice the last line was read in, which the automatic choice can
/// change from phrase to phrase.
class VoiceSpoken extends EngineEvent {
  const VoiceSpoken(this.name);

  final String? name;
}

/// This game's bank has grown. The count is the game's; the settings show
/// every game, so they are asked again rather than told.
class VoiceBankGrew extends EngineEvent {
  const VoiceBankGrew(this.size);

  final int size;
}

/// Where a stage actually ended up running, which is not always where it
/// was asked to.
class BackendSettled extends EngineEvent {
  const BackendSettled({required this.stage, required this.backend});

  final ComputeStage stage;
  final ComputeBackend backend;
}

/// A system-wide combination, pressed from inside the game.
class HotkeyPressed extends EngineEvent {
  const HotkeyPressed(this.action);

  final HotkeyAction action;
}

/// Something went wrong.
///
/// Usually a [LoreDubFailure], which the interface has words for; anything
/// else is a bug rather than a condition the application knows about, and
/// `describeFailure` shows it as it came -- unhelpful to translate, useful
/// to report. Typing this field more narrowly would mean inventing a code
/// for "something we did not foresee", which says less than the error
/// itself does.
class EngineFailed extends EngineEvent {
  const EngineFailed(this.failure);

  final Object failure;
}
