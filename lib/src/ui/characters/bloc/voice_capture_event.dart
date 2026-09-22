// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

part of 'voice_capture_bloc.dart';

sealed class VoiceCaptureEvent extends Equatable {
  const VoiceCaptureEvent();

  @override
  List<Object?> get props => const [];
}

/// The screen is up: which cards have a clip beside them is read.
final class VoiceCaptureOpened extends VoiceCaptureEvent {
  const VoiceCaptureOpened();
}

/// Starts or ends the session the recordings listen through. [process] is
/// the game to listen to, chosen on the screen.
final class RecordingSessionToggled extends VoiceCaptureEvent {
  const RecordingSessionToggled({required this.initializing, required this.process});

  final bool initializing;
  final GameProcess? process;

  @override
  List<Object?> get props => [initializing, process?.pid];
}

/// Ends the session this screen holds, recording or sample.
final class RecordingSessionEnded extends VoiceCaptureEvent {
  const RecordingSessionEnded();
}

/// Begins measuring what the game says for [id].
final class RecordingStarted extends VoiceCaptureEvent {
  const RecordingStarted(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// Closes the take and keeps what it heard as the character's voice.
final class RecordingStopped extends VoiceCaptureEvent {
  const RecordingStopped();
}

/// Measures the voice of [id] from the recordings the player dropped on it.
final class VoiceFilesDropped extends VoiceCaptureEvent {
  const VoiceFilesDropped(this.id, this.paths);

  final String id;
  final List<String> paths;

  @override
  List<Object?> get props => [id, paths];
}

/// Speaks a line in the voice the dubbing would read [id] in.
final class SampleAsked extends VoiceCaptureEvent {
  const SampleAsked(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// Plays back what [id] was recorded from.
final class ClipPlayed extends VoiceCaptureEvent {
  const ClipPlayed(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// Ends whatever is sounding -- a clip or a sample.
final class SoundStopped extends VoiceCaptureEvent {
  const SoundStopped();
}

final class _EngineSaid extends VoiceCaptureEvent {
  const _EngineSaid(this.event);

  final EngineEvent event;
}

final class _CastChanged extends VoiceCaptureEvent {
  const _CastChanged(this.library);

  final CharacterLibrary library;
}

final class _TakeTicked extends VoiceCaptureEvent {
  const _TakeTicked();
}
