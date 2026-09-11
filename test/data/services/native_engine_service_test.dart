// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/native_engine_service.dart';
import 'package:lore_dub/src/domain/failure.dart';

void main() {
  test('turns a native capture error into a failure the banner can show', () {
    final event = fromNativeEvent({
      'type': 'error',
      'message': 'English OCR language is not installed.',
    });

    expect(event['type'], 'error');
    final failure = event['failure']! as LoreDubFailure;
    expect(failure.code, FailureCode.captureFailed);
    expect(failure.detail, 'English OCR language is not installed.');
  });

  test('passes every other native event on untouched', () {
    const state = {'type': 'state', 'state': 'listening'};

    expect(fromNativeEvent(state), same(state));
  });

  test('names the action whose hotkey another program holds', () {
    final event = fromNativeEvent({'type': 'hotkeyTaken', 'action': 'resume'});

    expect(event['type'], 'error');
    expect(
      event['failure'],
      isA<LoreDubFailure>()
          .having((failure) => failure.code, 'code', FailureCode.hotkeyTaken)
          .having((failure) => failure.detail, 'detail', 'resume'),
    );
  });

  test('passes a hotkey press on for the pipeline to act on', () {
    final press = {'type': 'hotkey', 'action': 'pause'};

    expect(fromNativeEvent(press), same(press));
  });

  test('retries when a native string grows between size and copy', () {
    const initialValue = '[]';
    const grownValue = '[{"pid":42,"name":"Игра.exe"}]';
    final initialBytes = utf8.encode(initialValue);
    final grownBytes = utf8.encode(grownValue);
    var calls = 0;

    int reader(Pointer<Char> output, int capacity) {
      calls++;
      if (output == nullptr) return initialBytes.length;
      if (capacity <= grownBytes.length) return grownBytes.length;
      output.cast<Uint8>().asTypedList(capacity)
        ..setRange(0, grownBytes.length, grownBytes)
        ..[grownBytes.length] = 0;
      return grownBytes.length;
    }

    final result = readNativeUtf8String(
      reader,
      throwIfError: (code) => fail('Unexpected native error: $code'),
    );

    expect(result, grownValue);
    expect(calls, 3);
  });
}
