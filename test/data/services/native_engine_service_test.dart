// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/native_engine_service.dart';

void main() {
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
