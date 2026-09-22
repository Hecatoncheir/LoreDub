// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

part of 'session_bloc.dart';

sealed class SessionEvent extends Equatable {
  const SessionEvent();

  @override
  List<Object?> get props => const [];
}

/// A start button: one of the three kinds of session, started, or a start
/// still loading cancelled, or a session running ended.
///
/// One kind of event for the three so that they share one transformer:
/// a double-click lands its second press on whichever button the first
/// one was.
sealed class SessionToggle extends SessionEvent {
  const SessionToggle();
}

/// The start button of Эфир: starts live dubbing, cancels a start still
/// loading, or ends the dubbing that runs.
final class LiveToggled extends SessionToggle {
  const LiveToggled({required this.initializing});

  final bool initializing;

  @override
  List<Object?> get props => [initializing];
}

/// A start button of the Screen page, for one [reading] of the screen.
final class ScreenToggled extends SessionToggle {
  const ScreenToggled({required this.initializing, this.reading = ScreenReading.both});

  final bool initializing;
  final ScreenReading reading;

  @override
  List<Object?> get props => [initializing, reading];
}

/// The button that places the voices of the scene before anything is dubbed.
final class SceneToggled extends SessionToggle {
  const SceneToggled({required this.initializing});

  final bool initializing;

  @override
  List<Object?> get props => [initializing];
}

/// Ends the session, paused or not, and gives the game its volume back.
final class SessionStopped extends SessionEvent {
  const SessionStopped();
}

/// Rests a listening session without tearing it down.
final class SessionPaused extends SessionEvent {
  const SessionPaused();
}

final class SessionResumed extends SessionEvent {
  const SessionResumed();
}

/// The dashboard is up: from here on the session follows what the engine
/// says. Asked for rather than done as the bloc is made, so a screen staged
/// in a test is left standing as it was put.
final class EngineFollowed extends SessionEvent {
  const EngineFollowed();
}

final class _EngineSaid extends SessionEvent {
  const _EngineSaid(this.event);

  final EngineEvent event;
}
