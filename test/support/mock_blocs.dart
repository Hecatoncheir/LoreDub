// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lore_dub/src/ui/characters/bloc/cast_bloc.dart';
import 'package:lore_dub/src/ui/models/bloc/downloads_bloc.dart';
import 'package:lore_dub/src/ui/glossary/bloc/glossary_bloc.dart';
import 'package:lore_dub/src/ui/common/bloc/session_bloc.dart';
import 'package:lore_dub/src/ui/common/bloc/transcript_bloc.dart';
import 'package:lore_dub/src/ui/characters/bloc/voice_capture_bloc.dart';
import 'package:lore_dub/src/domain/app_release.dart';
import 'package:lore_dub/src/ui/shell/bloc/update_bloc.dart';

/// The glossary screen's state as a test says it is, and every event the
/// screen sends kept for the test to look at.
class MockGlossaryBloc extends MockBloc<GlossaryEvent, GlossaryState> implements GlossaryBloc {}

/// A glossary bloc standing still on [state], or moving through [then].
MockGlossaryBloc glossaryShowing(
  GlossaryState state, {
  Stream<GlossaryState> then = const Stream.empty(),
}) {
  final bloc = MockGlossaryBloc();
  whenListen(bloc, then, initialState: state);
  return bloc;
}

/// The characters screen's cards as a test says they are.
class MockCastBloc extends MockBloc<CastEvent, CastState> implements CastBloc {}

/// A cast bloc standing still on [state], or moving through [then].
MockCastBloc castShowing(CastState state, {Stream<CastState> then = const Stream.empty()}) {
  final bloc = MockCastBloc();
  whenListen(bloc, then, initialState: state);
  return bloc;
}

/// The characters screen's side of the engine as a test says it is. What
/// the cards can do besides is the installed models' and the settings'
/// answer, which the test stages as it stages them for any screen.
class MockVoiceCaptureBloc extends MockBloc<VoiceCaptureEvent, VoiceCaptureState>
    implements VoiceCaptureBloc {}

/// A capture bloc standing still on [state], or moving through [then].
MockVoiceCaptureBloc captureShowing(
  VoiceCaptureState state, {
  Stream<VoiceCaptureState> then = const Stream.empty(),
}) {
  final bloc = MockVoiceCaptureBloc();
  whenListen(bloc, then, initialState: state);
  return bloc;
}

/// The models screen's rows as a test says they are, a download under way
/// among them if it likes.
class MockDownloadsBloc extends MockBloc<DownloadsEvent, DownloadsState> implements DownloadsBloc {}

/// A downloads bloc standing still on [state], or moving through [then].
MockDownloadsBloc downloadsShowing(
  DownloadsState state, {
  Stream<DownloadsState> then = const Stream.empty(),
}) {
  final bloc = MockDownloadsBloc();
  whenListen(bloc, then, initialState: state);
  return bloc;
}

/// What `any` and `captureAny` stand in with for each kind of event, before
/// anything is captured. Called once from a test file's `setUpAll`.
void registerEventFallbacks() {
  registerFallbackValue(const GlossaryOpened());
  registerFallbackValue(const CastOpened());
  registerFallbackValue(const VoiceCaptureOpened());
  registerFallbackValue(const ModelDirectoryOpened());
  registerFallbackValue(const SessionStopped());
  registerFallbackValue(const TranscriptCleared());
  registerFallbackValue(const UpdatesChecked());
}

/// The dubbing screens' session as a test says it stands.
class MockSessionBloc extends MockBloc<SessionEvent, SessionState> implements SessionBloc {}

/// A session bloc standing still on [state], or moving through [then].
MockSessionBloc sessionShowing(
  SessionState state, {
  Stream<SessionState> then = const Stream.empty(),
}) {
  final bloc = MockSessionBloc();
  whenListen(bloc, then, initialState: state);
  return bloc;
}

/// What the dubbing screens' sessions have said, as a test says it.
class MockTranscriptBloc extends MockBloc<TranscriptEvent, TranscriptState>
    implements TranscriptBloc {}

/// A transcript bloc standing still on [state], or moving through [then].
MockTranscriptBloc transcriptShowing(
  TranscriptState state, {
  Stream<TranscriptState> then = const Stream.empty(),
}) {
  final bloc = MockTranscriptBloc();
  whenListen(bloc, then, initialState: state);
  return bloc;
}

/// The version row's state as a test says it stands.
class MockUpdateBloc extends MockBloc<UpdateEvent, UpdateState> implements UpdateBloc {}

/// An update bloc standing still on [state], or moving through [then].
MockUpdateBloc updatesShowing(
  UpdateState state, {
  Stream<UpdateState> then = const Stream.empty(),
}) {
  final bloc = MockUpdateBloc();
  whenListen(bloc, then, initialState: state);
  return bloc;
}
