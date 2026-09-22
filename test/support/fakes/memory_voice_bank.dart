// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:lore_dub/src/data/repositories/voice_bank_repository.dart';
import 'package:mocktail/mocktail.dart';

/// The kept voices with no disk behind them.
class MemoryVoiceBank extends Fake implements VoiceBankRepository {
  MemoryVoiceBank([this.count = 0]);

  int count;
  bool cleared = false;

  @override
  Future<String> fileFor(String game) async => 'voice_bank/$game.json';

  @override
  Future<int> size() async => count;

  @override
  Future<void> clear() async {
    cleared = true;
    count = 0;
  }
}
