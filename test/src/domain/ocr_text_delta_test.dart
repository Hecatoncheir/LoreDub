// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/ocr_text_delta.dart';

void main() {
  test('voices the first line whole', () {
    expect(freshOcrText(null, 'Where have you been?'), 'Where have you been?');
  });

  test('voices only what was added to a line that grew', () {
    expect(
      freshOcrText('Where have you been?', 'Where have you been? We waited all night.'),
      'We waited all night.',
    );
  });

  test('starts from the word where the two part', () {
    expect(
      freshOcrText('I told you to wait by the', 'I told you to wait by the gate, not the road.'),
      'gate, not the road.',
    );
    expect(
      freshOcrText('Hello wor', 'Hello world, how are you?'),
      'world, how are you?',
      reason: 'a word caught half-printed is voiced again in full',
    );
  });

  test('ignores the case and punctuation OCR reads differently each scan', () {
    expect(
      freshOcrText('- Где ты был?', '— где ты был. Мы ждали всю ночь'),
      'Мы ждали всю ночь',
    );
  });

  test('voices a different line whole', () {
    expect(
      freshOcrText('Where have you been?', 'The gate is locked.'),
      'The gate is locked.',
    );
    expect(
      freshOcrText('One two three four five', 'One two other words here'),
      'One two other words here',
      reason: 'less than half of the old line opens the new one',
    );
  });

  test('has nothing to voice when nothing was added', () {
    expect(freshOcrText('Where have you been?', 'Where have you been?'), isNull);
    expect(
      freshOcrText('- Где ты был?', 'где ты был'),
      isNull,
      reason: 'the same words, read with other punctuation, are the same line',
    );
    expect(freshOcrText('Where have you been? We waited.', 'Where have you been?'), isNull);
    expect(freshOcrText('Anything', '   '), isNull);
  });
}
