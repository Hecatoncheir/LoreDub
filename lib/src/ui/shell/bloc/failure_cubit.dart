// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_bloc/flutter_bloc.dart';

/// Where the parts of the dashboard put what went wrong.
///
/// Any stage can fail, but the interface shows one banner, so one place owns
/// the message and everyone else hands it over instead of keeping a copy.
abstract class FailureSink {
  void report(Object? error);
}

/// The failure banner: what went wrong, as raised, or null. The interface
/// writes it out (`describeFailure`).
///
/// A Cubit rather than a Bloc: reporting is one synchronous setter, and a
/// class of event for it would say nothing a call does not.
// A setter and nothing more: a Cubit on purpose (CLAUDE.md).
// ignore: prefer_bloc
class FailureCubit extends Cubit<Object?> implements FailureSink {
  FailureCubit() : super(null);

  @override
  void report(Object? error) {
    if (isClosed) return;
    emit(error);
  }
}
