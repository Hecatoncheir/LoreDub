// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:ffi';

import 'package:lore_dub/src/data/services/native_bridge.dart';
import 'package:lore_dub/src/data/services/native_engine_service.dart';
import 'package:mocktail/mocktail.dart';

/// The native library as a screen test needs it: every call answered from
/// memory and written down, and none of them reaching the DLL.
///
/// `flutter test` builds the native assets, so an engine left on its
/// default bridge loads the real library -- and a screen seeded with
/// settings then registers global hotkeys and draws the frame overlay on
/// the machine running the tests. The machine this answers for has no
/// processes, one monitor, no graphics adapter and no events to hand out.
class MemoryNative extends Fake implements NativeBridge {
  /// Every call made, by the name of the `ld_*` function it stands for.
  final calls = <String>[];

  /// What `ld_set_hotkeys` was last handed, or null before it was.
  String? hotkeys;

  /// What `ld_show_frame` last drew, or null while no frame is drawn.
  String? frame;

  int _answer(String call) {
    calls.add(call);
    return 0;
  }

  @override
  int start(String configJson) => _answer('ld_start');

  @override
  int stop() => _answer('ld_stop');

  @override
  int pollEvent(Pointer<Char> output, int capacity) => _answer('ld_poll_event_json');

  @override
  String errorMessage(int code) {
    calls.add('ld_error_message');
    return 'native error $code';
  }

  @override
  int setProcessVolume(int processId, double volume) => _answer('ld_set_process_volume');

  @override
  int restoreProcessVolumes() => _answer('ld_restore_process_volumes');

  @override
  int holdTake(int hold) => _answer('ld_hold_take');

  @override
  bool get processLoopbackSupported {
    calls.add('ld_is_process_loopback_supported');
    return true;
  }

  @override
  String processesJson() {
    calls.add('ld_list_processes_json');
    return '[]';
  }

  @override
  String monitorsJson() {
    calls.add('ld_list_monitors_json');
    return '[{"left":0,"top":0,"right":1920,"bottom":1080,"primary":true}]';
  }

  @override
  String graphicsJson() {
    calls.add('ld_probe_graphics_json');
    return '{"adapters":[]}';
  }

  @override
  int setPaused({required bool paused}) => _answer('ld_set_paused');

  @override
  int setHotkeys(String configJson) {
    hotkeys = configJson;
    return _answer('ld_set_hotkeys');
  }

  @override
  int showFrame(String configJson) {
    frame = configJson;
    return _answer('ld_show_frame');
  }

  @override
  int hideFrame() {
    frame = null;
    return _answer('ld_hide_frame');
  }

  @override
  void stopWave() => _answer('ld_stop_wave');
}

/// An engine over [native], or over a [MemoryNative] of its own: what a
/// test builds wherever the application would build a [NativeEngineService].
NativeEngineService memoryEngine([NativeBridge? native]) =>
    NativeEngineService(native: native ?? MemoryNative());
