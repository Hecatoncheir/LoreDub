// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/ocr_text_delta.dart';

void main() {
  test('voices the first text whole, its lines joined', () {
    expect(
      freshOcrText(null, 'Where have you been?\nWe waited.'),
      'Where have you been? We waited.',
    );
  });

  test('voices only what was added to a text that is mostly the same', () {
    expect(
      freshOcrText('Where have you been?', 'Where have you been? We waited all night.'),
      'We waited all night.',
    );
    expect(
      freshOcrText('Captain:\nHold the line.', 'Captain:\nHold the line.\nFall back!'),
      'Fall back!',
    );
    expect(
      freshOcrText('Captain:\nHold the line.', 'Captain:\nNow!\nHold the line.'),
      'Now!',
      reason: 'a line put in between is new too',
    );
  });

  test('voices a half-printed word again in full', () {
    expect(
      freshOcrText('I told you to wait by the ga', 'I told you to wait by the gate, not the road.'),
      'gate, not the road.',
    );
  });

  test('takes a word read differently for a misreading, not for new text', () {
    expect(
      freshOcrText('Where have you bcen? We waited.', 'Where have you been? We waited.'),
      isNull,
    );
  });

  test('ignores the case and punctuation OCR reads differently each scan', () {
    expect(
      freshOcrText('- Где ты был?\nМы ждали', '— где ты был.\nМы ждали всю ночь'),
      'всю ночь',
    );
  });

  test('voices the whole text when little of it is the same', () {
    expect(freshOcrText('Where have you been?', 'The gate is locked.'), 'The gate is locked.');
    expect(
      freshOcrText('Captain:\nHold the line.', 'Captain:\nFall back now.'),
      'Captain: Fall back now.',
      reason: 'one word in four is not most of the text',
    );
  });

  test('has nothing to voice when nothing was added', () {
    expect(freshOcrText('Where have you been?', 'Where have you been?'), isNull);
    expect(
      freshOcrText('- Где ты был?', 'где ты был'),
      isNull,
      reason: 'the same words, read with other punctuation, are the same text',
    );
    expect(freshOcrText('Captain:\nHold the line.\nNow!', 'Captain:\nHold the line.'), isNull);
    expect(freshOcrText('Anything', '   '), isNull);
  });
}
