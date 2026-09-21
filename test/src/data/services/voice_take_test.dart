// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/voice_take.dart';

void main() {
  late List<int> held;
  late List<String> discarded;
  late int gathered;
  late VoiceTake take;

  setUp(() {
    held = [];
    discarded = [];
    gathered = 0;
    take = VoiceTake(
      hold: (hold) {
        held.add(hold);
        return hold == 0 ? gathered : 0;
      },
      discard: (path) async => discarded.add(path),
    );
  });

  test('keeps what was measured while it ran, and nothing between takes', () {
    expect(take.keep('before.wav'), isFalse, reason: 'heard between takes');

    take.open();
    expect(held, [1]);
    expect(take.recording, isTrue);
    expect(take.keep('line.wav'), isTrue);
  });

  test('closing a silent take waits for nothing', () async {
    take.open();

    await take.close();

    expect(held, [1, 0]);
    expect(take.recording, isFalse);
  });

  test('closing waits for the recording it leaves behind to be measured', () async {
    gathered = 48000;
    take.open();

    var closed = false;
    final closing = take.close().then((_) => closed = true);
    await Future<void>.delayed(Duration.zero);
    expect(closed, isFalse, reason: 'the card is nothing without that recording');

    take.measured();
    await closing;
    expect(closed, isTrue);
  });

  test('a new take lets go of the clips the last one kept', () {
    take
      ..open()
      ..keep('first.wav');
    take.open();

    expect(discarded, ['first.wav']);
  });

  test('a session ending lets the take go and ends a wait for it', () async {
    gathered = 48000;
    take
      ..open()
      ..keep('line.wav');
    final closing = take.close();

    take.abandon();
    await closing;

    expect(take.recording, isFalse);
    expect(discarded, ['line.wav']);
  });
}
