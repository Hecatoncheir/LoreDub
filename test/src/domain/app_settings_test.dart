// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/app_settings.dart';

void main() {
  test('holds the game above what the capture can still hear', () {
    // Windows takes the loopback tap after the session volume, so a game
    // silenced outright is a pipeline listening to silence.
    const silenced = AppSettings(originalVolume: 0);
    expect(silenced.quietestDuck, AppSettings.audibleDuck);
    expect(silenced.duckedVolume, AppSettings.audibleDuck);

    expect(const AppSettings(originalVolume: 0.3).duckedVolume, 0.3);
    expect(const AppSettings(originalVolume: 0.9).duckedVolume, AppSettings.loudestDuck);
  });

  test('lets subtitle mode silence the game, having no ear in it', () {
    const subtitles = AppSettings(captureMode: CaptureMode.ocr, originalVolume: 0);

    expect(subtitles.quietestDuck, 0);
    expect(subtitles.duckedVolume, 0);
  });

  test('moves the volume in the same steps whichever screen sets it', () {
    // The settings screen and the node panel read these, so a number set on
    // one is a number the other can set again.
    expect(const AppSettings().duckDivisions, 20);
    expect(const AppSettings(captureMode: CaptureMode.ocr).duckDivisions, 25);
    expect(AppSettings.duckStep, 0.02);
  });

  test('turns the game down for the whole session until told otherwise', () {
    expect(const AppSettings().duckWhileSpeaking, isFalse);
    expect(const AppSettings().copyWith(duckWhileSpeaking: true).duckWhileSpeaking, isTrue);
  });
}
