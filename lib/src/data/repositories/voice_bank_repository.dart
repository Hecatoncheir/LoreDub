// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../services/voice_bank_service.dart';

/// The voices each game's dubbing has met, kept a file per game.
///
/// The sessions are handed the file of the game they run over, and the
/// settings screen counts and clears what every game has kept.
class VoiceBankRepository {
  VoiceBankRepository([VoiceBankService? service]) : _service = service ?? VoiceBankService();

  final VoiceBankService _service;

  /// The bank file the original voice keeps [game]'s characters in; the game
  /// is named by its executable.
  Future<String> fileFor(String game) => _service.fileFor(game);

  /// How many voices the banks of all games hold together.
  Future<int> size() => _service.count();

  Future<void> clear() => _service.clear();
}
