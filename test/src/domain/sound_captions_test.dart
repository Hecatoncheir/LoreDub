// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/sound_captions.dart';

void main() {
  test('leaves nothing of a line that only captions a sound', () {
    expect(withoutSoundCaptions('(soft music)'), '');
    expect(withoutSoundCaptions('(мягкая музыка)'), '');
    expect(withoutSoundCaptions('[Music]'), '');
    expect(withoutSoundCaptions('[BLANK_AUDIO]'), '');
    expect(withoutSoundCaptions('*laughs*'), '');
    expect(withoutSoundCaptions('♪ ♪'), '');
    expect(withoutSoundCaptions('♪ la la la ♪'), '');
    expect(withoutSoundCaptions('- (door creaks) -'), '', reason: 'dashes alone are not speech');
  });

  test('leaves nothing of a caption the segment cut in half', () {
    expect(withoutSoundCaptions('(light music'), '');
    expect(withoutSoundCaptions('music playing)'), '');
    expect(withoutSoundCaptions('[gunfire'), '');
  });

  test('keeps the words spoken around a caption', () {
    expect(withoutSoundCaptions('(whispering) Come here.'), 'Come here.');
    expect(withoutSoundCaptions('Get down! [gunfire] Now!'), 'Get down! Now!');
    expect(withoutSoundCaptions('Where have you been?'), 'Where have you been?');
    expect(withoutSoundCaptions('Мы ждали всю ночь'), 'Мы ждали всю ночь');
  });
}
