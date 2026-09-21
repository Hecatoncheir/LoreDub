// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/cast_bloc.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/downloads_bloc.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/glossary_bloc.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/voice_capture_bloc.dart';

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
/// the cards can do is asked of the bloc itself, so the three answers are
/// stubbed: everything installed unless the test says otherwise.
class MockVoiceCaptureBloc extends MockBloc<VoiceCaptureEvent, VoiceCaptureState>
    implements VoiceCaptureBloc {}

/// A capture bloc standing still on [state], or moving through [then].
MockVoiceCaptureBloc captureShowing(
  VoiceCaptureState state, {
  Stream<VoiceCaptureState> then = const Stream.empty(),
  bool canRecord = true,
  bool canPreview = true,
  bool carriesTimbre = true,
}) {
  final bloc = MockVoiceCaptureBloc();
  whenListen(bloc, then, initialState: state);
  when(() => bloc.canRecord).thenReturn(canRecord);
  when(() => bloc.canPreview).thenReturn(canPreview);
  when(() => bloc.carriesTimbre).thenReturn(carriesTimbre);
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
}
