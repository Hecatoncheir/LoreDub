// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

#ifndef LORE_DUB_NATIVE_H_
#define LORE_DUB_NATIVE_H_

#include <stdint.h>

#if defined(_WIN32)
#define LD_API __declspec(dllexport)
#else
#define LD_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Returns the native bridge ABI version.
LD_API int32_t ld_abi_version(void);

// Returns 1 when the current platform supports process-loopback capture.
LD_API int32_t ld_is_process_loopback_supported(void);

// Writes a UTF-8 JSON array of candidate game processes. Returns the number of
// bytes required, excluding the trailing NUL. If capacity is too small, no
// partial JSON is written.
LD_API int32_t ld_list_processes_json(char* output, int32_t capacity);

// Writes a UTF-8 JSON object describing the graphics adapters and the GPU
// driver libraries that are installed. Returns the number of bytes required,
// excluding the trailing NUL. If capacity is too small, nothing is written.
LD_API int32_t ld_probe_graphics_json(char* output, int32_t capacity);

// Sets the volume of every render session owned by process_id. Volume is in
// the inclusive [0, 1] range. Returns 0 on success or a negative error code.
LD_API int32_t ld_set_process_volume(uint32_t process_id, float volume);

// Restores all sessions changed through ld_set_process_volume.
LD_API int32_t ld_restore_process_volumes(void);

// Plays a PCM WAV file synchronously through the current default output.
LD_API int32_t ld_play_wave(const char* utf8_path);

// Starts/stops the real-time pipeline. Config is a UTF-8 JSON object. Events
// are retrieved using ld_poll_event_json.
LD_API int32_t ld_start(const char* config_json);
LD_API int32_t ld_stop(void);

// Pops one UTF-8 JSON event. Returns 0 when the queue is empty, a positive
// byte count on success/required capacity, or a negative error code.
LD_API int32_t ld_poll_event_json(char* output, int32_t capacity);

// Returns a stable UTF-8 error description for a native error code.
LD_API const char* ld_error_message(int32_t error_code);

#ifdef __cplusplus
}
#endif

#endif  // LORE_DUB_NATIVE_H_
