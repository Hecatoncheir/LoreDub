// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/wave_slices.dart';

void main() {
  const rate = 16000;

  /// A mono 16-bit recording [seconds] long, every sample its own number so
  /// a piece can be told from where it was cut.
  Uint8List recording(double seconds) {
    final frames = (rate * seconds).round();
    final wave = Uint8List(44 + frames * 2);
    final bytes = ByteData.sublistView(wave);
    void tag(int offset, String name) =>
        wave.setRange(offset, offset + name.length, name.codeUnits);
    tag(0, 'RIFF');
    bytes.setUint32(4, 36 + frames * 2, Endian.little);
    tag(8, 'WAVE');
    tag(12, 'fmt ');
    bytes
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, 1, Endian.little)
      ..setUint32(24, rate, Endian.little)
      ..setUint32(28, rate * 2, Endian.little)
      ..setUint16(32, 2, Endian.little)
      ..setUint16(34, 16, Endian.little);
    tag(36, 'data');
    bytes.setUint32(40, frames * 2, Endian.little);
    for (var frame = 0; frame < frames; frame++) {
      bytes.setInt16(44 + frame * 2, frame % 32000, Endian.little);
    }
    return wave;
  }

  double lengthOf(Uint8List piece) {
    final bytes = ByteData.sublistView(piece);
    return bytes.getUint32(40, Endian.little) / (rate * 2);
  }

  test('cuts a recording where the voice changes', () {
    final pieces = sliceWave(recording(6), [2, 4.5]);

    expect(pieces.length, 3);
    expect(lengthOf(pieces[0]), closeTo(2, 0.001));
    expect(lengthOf(pieces[1]), closeTo(2.5, 0.001));
    expect(lengthOf(pieces[2]), closeTo(1.5, 0.001));
  });

  test('writes pieces that read back as recordings of their own', () {
    final piece = sliceWave(recording(4), [1]).first;
    final bytes = ByteData.sublistView(piece);

    expect(String.fromCharCodes(piece, 0, 4), 'RIFF');
    expect(String.fromCharCodes(piece, 8, 12), 'WAVE');
    expect(bytes.getUint16(22, Endian.little), 1, reason: 'mono, as it was captured');
    expect(bytes.getUint32(24, Endian.little), rate);
    expect(bytes.getUint32(4, Endian.little), piece.lengthInBytes - 8);
    // The second piece starts where the first ended.
    expect(
      ByteData.sublistView(sliceWave(recording(4), [1])[1]).getInt16(44, Endian.little),
      rate % 32000,
    );
  });

  test('hands back the recording whole when there is nothing to cut', () {
    final whole = recording(3);

    expect(sliceWave(whole, const []), [whole]);
    expect(sliceWave(whole, [0]), [whole], reason: 'a cut at the very start divides nothing');
    expect(sliceWave(whole, [9]), [whole], reason: 'past the end of the recording');
    expect(sliceWave(Uint8List.fromList('not a wave'.codeUnits), [1]).length, 1);
  });
}
