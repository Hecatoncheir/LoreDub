// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/compute_device.dart';

void main() {
  test('holds the game above what the capture can still hear', () {
    // Windows takes the loopback tap after the session volume, so a game
    // silenced outright is a pipeline listening to silence.
    const silenced = AppSettings(originalVolume: 0);
    expect(silenced.duckedVolume, AppSettings.audibleDuck);

    expect(const AppSettings(originalVolume: 0.3).duckedVolume, 0.3);
    expect(const AppSettings(originalVolume: 0.9).duckedVolume, AppSettings.loudestDuck);
  });

  test('reads at the same pace whichever screen sets it', () {
    // The node panel offered 0.8 to 1.6 in steps of 0.05 while the settings
    // screen offered 0.9 to 1.35 in steps of 0.025: a pace set on one was
    // not one the other could set again.
    expect(AppSettings.speechDivisions, 18);
    expect(const AppSettings(ttsSpeed: 1.2).chosenSpeed, 1.2);
    expect(const AppSettings(ttsSpeed: 1.6).chosenSpeed, AppSettings.fastestSpeech);
    expect(const AppSettings(ttsSpeed: 0.8).chosenSpeed, AppSettings.slowestSpeech);
  });

  test('moves the volume in the same steps whichever screen sets it', () {
    // The settings screen and the node panel read these, so a number set on
    // one is a number the other can set again.
    expect(AppSettings.duckDivisions, 20);
    expect(AppSettings.duckStep, 0.02);
  });

  test('steps the game aside for each line, and hurries a queue', () {
    const settings = AppSettings();

    expect(settings.duckWhileSpeaking, isTrue);
    expect(settings.hurryWhenQueued, isTrue);

    // Both are the player's to refuse: off, the game stays turned down from
    // start to stop, and every line is read at the pace they set.
    expect(settings.copyWith(duckWhileSpeaking: false).duckWhileSpeaking, isFalse);
    expect(settings.copyWith(hurryWhenQueued: false).hurryWhenQueued, isFalse);
  });

  test('binds and unbinds a combination by the action it answers to', () {
    const settings = AppSettings();

    for (final action in HotkeyAction.values) {
      final unbound = settings.withHotkey(action, null);
      expect(unbound.hotkeyFor(action), isNull, reason: action.name);
      final other = HotkeyAction.values.firstWhere((each) => each != action);
      expect(unbound.hotkeyFor(other), settings.hotkeyFor(other), reason: action.name);

      const f9 = Hotkey(keyCode: 0x78, label: 'F9');
      expect(unbound.withHotkey(action, f9).hotkeyFor(action), f9, reason: action.name);
    }
  });

  test('two settings are equal when they would be written the same', () {
    const a = AppSettings(ttsSpeed: 1.2);
    expect(a, const AppSettings(ttsSpeed: 1.2));
    expect(a.hashCode, const AppSettings(ttsSpeed: 1.2).hashCode);
    expect(a, isNot(const AppSettings(ttsSpeed: 1.3)));
    expect(
      a.withHotkey(HotkeyAction.pause, null),
      isNot(a),
      reason: 'a removed combination is a change',
    );
    expect(
      a.withBackend(ComputeStage.speech, ComputeBackend.cuda).withComputeDevice(ComputeDevice.auto),
      a,
      reason: 'a preset drops every pin',
    );
  });
}
