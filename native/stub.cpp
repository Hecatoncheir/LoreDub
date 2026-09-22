// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// The library as it is built anywhere but Windows, where there is nothing to
// capture, read or play through: every call is answered as unsupported, and
// the lists come back empty. It exists so that the build hook has something
// to compile on the Linux CI job; the real sources stay free of fences.

#include "lore_dub_native.h"

#include "abi_buffer.h"

namespace {

constexpr int32_t kUnsupported = -2;

}  // namespace

int32_t ld_abi_version(void) { return 1; }

int32_t ld_is_process_loopback_supported(void) { return 0; }

int32_t ld_list_processes_json(char* output, int32_t capacity) {
  return WriteString("[]", output, capacity);
}

int32_t ld_list_monitors_json(char* output, int32_t capacity) {
  return WriteString("[]", output, capacity);
}

int32_t ld_probe_graphics_json(char* output, int32_t capacity) {
  return WriteString("{\"adapters\":[],\"cudaDriver\":false,\"vulkanLoader\":false}", output,
                     capacity);
}

int32_t ld_set_process_volume(uint32_t, float) { return kUnsupported; }

int32_t ld_restore_process_volumes(void) { return kUnsupported; }

int32_t ld_play_wave(const char*) { return kUnsupported; }

int32_t ld_stop_wave(void) { return kUnsupported; }

int32_t ld_decode_audio(const char*, const char*) { return kUnsupported; }

int32_t ld_start(const char*) { return kUnsupported; }

int32_t ld_stop(void) { return 0; }

int32_t ld_hold_take(int32_t) { return kUnsupported; }

int32_t ld_set_paused(int32_t) { return 0; }

int32_t ld_set_hotkeys(const char*) { return kUnsupported; }

int32_t ld_show_frame(const char*) { return kUnsupported; }

int32_t ld_hide_frame(void) { return kUnsupported; }

int32_t ld_poll_event_json(char*, int32_t) { return 0; }

const char* ld_error_message(int32_t error_code) {
  switch (error_code) {
    case 0: return "Success";
    case kUnsupported: return "Feature is unsupported on this platform";
    default: return "Unknown native error";
  }
}
