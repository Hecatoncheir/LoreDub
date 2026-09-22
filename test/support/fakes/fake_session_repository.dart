// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:lore_dub/src/data/repositories/session_repository.dart';
import 'package:lore_dub/src/domain/engine_event.dart';
import 'package:mocktail/mocktail.dart';

/// The engine and its sessions with nothing behind them: what the engine
/// says is whatever the test adds to [said], a stop does nothing, disposal
/// closes [said], and any other call throws -- a test that starts a session
/// fakes that start itself, by extending this.
class FakeSessionRepository extends Fake implements SessionRepository {
  final said = StreamController<EngineEvent>.broadcast();

  @override
  Stream<EngineEvent> get events => said.stream;

  @override
  Future<void> stop() async {}

  @override
  void dispose() => unawaited(said.close());
}
