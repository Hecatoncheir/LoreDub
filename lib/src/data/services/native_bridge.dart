// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../../domain/failure.dart';
import '../../native/lore_dub_native.g.dart';

typedef NativeStringReader = int Function(Pointer<Char> output, int capacity);

/// A call into the library that answered with an error code.
///
/// A [LoreDubFailure] rather than an exception of its own: it reaches the
/// banner like everything else, and `describeFailure` shows anything that
/// is not one as it came -- so this used to be read by the player as
/// `NativeEngineException(-3): ...`.
LoreDubFailure nativeCallFailed(int code, String message) =>
    LoreDubFailure(FailureCode.nativeCallFailed, detail: '$code: $message');

/// Every call the engine makes into the native library, in Dart's own types.
///
/// The one place pointers are made and freed and strings are read back, so
/// the engine above it holds none. It is also the engine's seam: the tests
/// load no native library, and a test answers in its place by implementing
/// this on `Fake` -- extended, whatever it did not override reached the
/// library. Answers are the library's codes,
/// negative for an error, which the engine words through [errorMessage];
/// what is read back as a string throws on one instead.
class NativeBridge {
  const NativeBridge();

  /// `ld_start`, given the capture as the JSON it crosses the boundary as.
  int start(String configJson) => _withString(configJson, (config) => ld_start(config));

  /// `ld_stop`: ends the capture and drops the hotkeys with it.
  int stop() => ld_stop();

  /// `ld_poll_event_json`, read the way every native string is.
  int pollEvent(Pointer<Char> output, int capacity) => ld_poll_event_json(output, capacity);

  /// `ld_error_message`: what a negative answer from any of them means.
  String errorMessage(int code) => ld_error_message(code).cast<Utf8>().toDartString();

  /// Turns a process down to [volume], a share of its own.
  int setProcessVolume(int processId, double volume) => ld_set_process_volume(processId, volume);

  /// Gives every process that was turned down its volume back.
  int restoreProcessVolumes() => ld_restore_process_volumes();

  /// Holds the capture's take open (1) or lets it go (0), answering with
  /// how much a take let go of had gathered.
  int holdTake(int hold) => ld_hold_take(hold);

  /// Whether this Windows can take one process's sound on its own.
  bool get processLoopbackSupported => ld_is_process_loopback_supported() == 1;

  /// The processes running, as JSON.
  String processesJson() => _read(ld_list_processes_json);

  /// Where the monitors stand, as JSON.
  String monitorsJson() => _read(ld_list_monitors_json);

  /// The machine's graphics adapters and drivers, as JSON.
  String graphicsJson() => _read(ld_probe_graphics_json);

  /// Rests the capture (it drops what it finishes) or picks it up again.
  int setPaused({required bool paused}) => ld_set_paused(paused ? 1 : 0);

  /// Registers the keys [configJson] names, dropping the ones before.
  int setHotkeys(String configJson) => _withString(configJson, (config) => ld_set_hotkeys(config));

  /// Draws the subtitle frame over the game, or moves the one drawn.
  int showFrame(String configJson) => _withString(configJson, (config) => ld_show_frame(config));

  /// Takes that frame off the screen.
  int hideFrame() => ld_hide_frame();

  /// Ends whatever is sounding.
  void stopWave() => ld_stop_wave();

  /// Decodes [source] into 16 kHz mono WAV at [target], answering with the
  /// length in milliseconds or a negative code.
  ///
  /// Static, as is [playWave], because both run in an isolate of their own
  /// -- a long file is a wait rather than a moment -- and a closure over an
  /// instance would take the instance along into the message.
  static int decodeAudio(String source, String target) =>
      _withString(source, (from) => _withString(target, (to) => ld_decode_audio(from, to)));

  /// Plays [wavePath] to its end, failing as the library says it did.
  static void playWave(String wavePath) {
    final code = _withString(wavePath, (path) => ld_play_wave(path));
    if (code < 0) {
      throw nativeCallFailed(code, ld_error_message(code).cast<Utf8>().toDartString());
    }
  }

  String _read(NativeStringReader reader) => readNativeUtf8String(
    reader,
    throwIfError: (code) => throw nativeCallFailed(code, errorMessage(code)),
  );

  /// Calls [call] with [value] as a C string, freed once it has answered.
  static int _withString(String value, int Function(Pointer<Char> pointer) call) {
    final pointer = value.toNativeUtf8();
    try {
      return call(pointer.cast());
    } finally {
      malloc.free(pointer);
    }
  }
}

/// Reads a string the library writes into a buffer of the caller's: asked
/// for its length first, then copied.
String readNativeUtf8String(
  NativeStringReader reader, {
  bool emptyAllowed = false,
  required void Function(int code) throwIfError,
}) {
  var required = reader(nullptr, 0);
  if (required < 0) throwIfError(required);
  if (required == 0 && emptyAllowed) return '';

  // A native value can grow between the size query and the copy (for example,
  // when a Windows process starts while the process list is being built).
  // Retry with the newly reported size instead of decoding an untouched or
  // undersized buffer.
  for (var attempt = 0; attempt < 8; attempt++) {
    final capacity = required + 1;
    final buffer = calloc<Char>(capacity);
    try {
      final written = reader(buffer, capacity);
      if (written < 0) throwIfError(written);
      if (written < capacity) {
        return buffer.cast<Utf8>().toDartString(length: written);
      }
      required = written;
    } finally {
      calloc.free(buffer);
    }
  }

  // Eight tries at a value that grows between the size query and the copy
  // is a library that is not going to settle. Raised as a failure rather
  // than a `FormatException`, which the banner printed as it came.
  throw const LoreDubFailure(
    FailureCode.nativeCallFailed,
    detail: 'a native value kept changing while it was being read',
  );
}
