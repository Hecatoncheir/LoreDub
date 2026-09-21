// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/game_ducker.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/session_config.dart';

void main() {
  late List<(int, double)> turned;
  late int restored;
  late GameDucker ducker;

  setUp(() {
    turned = [];
    restored = 0;
    ducker = GameDucker(
      setVolume: (processId, volume) {
        turned.add((processId, volume));
        return 0;
      },
      restore: () => restored++,
    );
  });

  const worker = WorkerPlan(threads: 2, pythonExecutable: 'python.exe', runtimeDirectory: 'rt');

  LiveSessionConfig live({
    bool duckWhileSpeaking = false,
    int processId = 42,
    AudioCaptureSource source = AudioCaptureSource.process,
  }) => LiveSessionConfig(
    worker: worker,
    capture: CapturePlan(mode: CaptureMode.audio, processId: processId, audioSource: source),
    lines: LineRules(
      targetLanguage: 'ru',
      duckWhileSpeaking: duckWhileSpeaking,
      duckVolume: 0.25,
    ),
  );

  test('turns the game down for the session, and again after a rest', () {
    ducker.begin(live());
    expect(turned, [(42, 0.25)]);

    ducker.rest();
    expect(restored, 1, reason: 'the game plays at its own volume while dubbing rests');

    ducker.resume();
    expect(turned, [(42, 0.25), (42, 0.25)]);

    ducker.end();
    expect(restored, 2);
  });

  test('for a line rather than the session, only while the dubbing speaks', () {
    ducker.begin(live(duckWhileSpeaking: true));
    expect(turned, isEmpty);

    ducker.speaking(speaking: true);
    expect(turned, [(42, 0.25)]);
    ducker.speaking(speaking: false);
    expect(restored, 1);

    ducker.resume();
    expect(turned, hasLength(1), reason: 'a resume brings back no session-long duck');
  });

  test('turns nothing down where no game is named or the whole output is heard', () {
    ducker
      ..begin(live(processId: 0))
      ..speaking(speaking: true)
      ..begin(live(source: AudioCaptureSource.system));

    expect(turned, isEmpty);
  });

  test('turns the game down while the screen is read, whatever sound is taken', () {
    ducker.begin(
      const ScreenSessionConfig(
        worker: worker,
        capture: CapturePlan(mode: CaptureMode.ocr, processId: 7),
        lines: LineRules(targetLanguage: 'ru', duckVolume: 0.1),
      ),
    );

    expect(turned, [(7, 0.1)]);
  });

  test('a session that reads no lines is never turned down for', () {
    ducker
      ..begin(
        const SceneSessionConfig(
          worker: worker,
          capture: CapturePlan(mode: CaptureMode.audio, processId: 7),
        ),
      )
      ..speaking(speaking: true);

    expect(turned, isEmpty);
  });
}
