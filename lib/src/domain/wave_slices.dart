// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:typed_data';

/// The header a piece is written with: the canonical 44 bytes of a PCM WAV.
const _headerBytes = 44;

/// Cuts a 16-bit PCM WAV into the pieces [seconds] marks off.
///
/// The captured audio of one segment can hold two characters answering each
/// other, and each of them wants recognition and a voice of their own. A
/// recording this cannot read — another encoding, a damaged header — comes
/// back whole rather than half cut, since a phrase heard as one piece is
/// still a phrase.
List<Uint8List> sliceWave(Uint8List wave, List<double> seconds) {
  final clip = _WaveClip.read(wave);
  if (clip == null || seconds.isEmpty) return [wave];
  final frames = clip.samples.lengthInBytes ~/ clip.frameBytes;
  final bounds = <int>{0, frames};
  for (final second in seconds) {
    final frame = (second * clip.rate).round();
    if (frame > 0 && frame < frames) bounds.add(frame);
  }
  final ordered = bounds.toList()..sort();
  if (ordered.length < 3) return [wave];
  return [
    for (var index = 1; index < ordered.length; index++)
      clip.pieceOf(ordered[index - 1], ordered[index]),
  ];
}

/// What a piece needs from the recording it is cut out of.
class _WaveClip {
  _WaveClip({
    required this.channels,
    required this.rate,
    required this.bitsPerSample,
    required this.samples,
  });

  /// The format and the samples of a PCM WAV, or null for anything else.
  static _WaveClip? read(Uint8List wave) {
    if (wave.lengthInBytes < 12) return null;
    final bytes = ByteData.sublistView(wave);
    if (_tag(wave, 0) != 'RIFF' || _tag(wave, 8) != 'WAVE') return null;
    var channels = 0;
    var rate = 0;
    var bitsPerSample = 0;
    Uint8List? samples;
    var offset = 12;
    while (offset + 8 <= wave.lengthInBytes) {
      final name = _tag(wave, offset);
      final length = bytes.getUint32(offset + 4, Endian.little);
      final body = offset + 8;
      final available = length > wave.lengthInBytes - body ? wave.lengthInBytes - body : length;
      if (name == 'fmt ' && available >= 16) {
        if (bytes.getUint16(body, Endian.little) != 1) return null;
        channels = bytes.getUint16(body + 2, Endian.little);
        rate = bytes.getUint32(body + 4, Endian.little);
        bitsPerSample = bytes.getUint16(body + 14, Endian.little);
      } else if (name == 'data') {
        samples = Uint8List.sublistView(wave, body, body + available);
      }
      // Chunks are padded to an even length.
      offset = body + length + (length.isOdd ? 1 : 0);
    }
    if (samples == null || channels <= 0 || rate <= 0 || bitsPerSample != 16) return null;
    return _WaveClip(
      channels: channels,
      rate: rate,
      bitsPerSample: bitsPerSample,
      samples: samples,
    );
  }

  final int channels;
  final int rate;
  final int bitsPerSample;
  final Uint8List samples;

  int get frameBytes => channels * bitsPerSample ~/ 8;

  /// The frames from [first] up to [last], as a WAV of their own.
  Uint8List pieceOf(int first, int last) {
    final body = Uint8List.sublistView(
      samples,
      first * frameBytes,
      last * frameBytes,
    );
    final piece = Uint8List(_headerBytes + body.lengthInBytes);
    final bytes = ByteData.sublistView(piece);
    _write(piece, 0, 'RIFF');
    bytes.setUint32(4, 36 + body.lengthInBytes, Endian.little);
    _write(piece, 8, 'WAVE');
    _write(piece, 12, 'fmt ');
    bytes
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, channels, Endian.little)
      ..setUint32(24, rate, Endian.little)
      ..setUint32(28, rate * frameBytes, Endian.little)
      ..setUint16(32, frameBytes, Endian.little)
      ..setUint16(34, bitsPerSample, Endian.little);
    _write(piece, 36, 'data');
    bytes.setUint32(40, body.lengthInBytes, Endian.little);
    piece.setRange(_headerBytes, piece.lengthInBytes, body);
    return piece;
  }
}

String _tag(Uint8List wave, int offset) => String.fromCharCodes(
  wave,
  offset,
  offset + 4 > wave.lengthInBytes ? wave.lengthInBytes : offset + 4,
);

void _write(Uint8List target, int offset, String tag) =>
    target.setRange(offset, offset + tag.length, tag.codeUnits);
