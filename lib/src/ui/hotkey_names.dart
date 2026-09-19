// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../l10n/app_localizations.dart';
import '../domain/hotkey.dart';

/// What [action] is called in the interface.
String hotkeyActionName(AppLocalizations l10n, HotkeyAction action) => switch (action) {
  HotkeyAction.pause => l10n.hotkeyPause,
  HotkeyAction.resume => l10n.hotkeyResume,
  HotkeyAction.snapshot => l10n.hotkeySnapshot,
  HotkeyAction.frame => l10n.hotkeyFrame,
  HotkeyAction.frameOverlay => l10n.hotkeyFrameOverlay,
};

/// Why a combination cannot be bound, in the interface language.
String describeHotkeyProblem(AppLocalizations l10n, HotkeyProblem problem) => switch (problem) {
  HotkeyTakesGameKey() => l10n.hotkeyNeedsModifier,
  HotkeyAlreadyBound(:final action) => l10n.hotkeyDuplicate(hotkeyActionName(l10n, action)),
};
