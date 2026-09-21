// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:bloc_test/bloc_test.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/glossary_bloc.dart';

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
