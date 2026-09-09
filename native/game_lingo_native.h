// Copyright (c) 2026 GameLingo contributors.
// SPDX-License-Identifier: MIT

#ifndef GAME_LINGO_NATIVE_H_
#define GAME_LINGO_NATIVE_H_

#include <stdint.h>

#if defined(_WIN32)
#define GL_API __declspec(dllexport)
#else
#define GL_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Returns the native bridge ABI version.
GL_API int32_t gl_abi_version(void);

// Returns 1 when the current platform supports process-loopback capture.
GL_API int32_t gl_is_process_loopback_supported(void);

// Writes a UTF-8 JSON array of candidate game processes. Returns the number of
// bytes required, excluding the trailing NUL. If capacity is too small, no
// partial JSON is written.
GL_API int32_t gl_list_processes_json(char* output, int32_t capacity);

// Sets the volume of every render session owned by process_id. Volume is in
// the inclusive [0, 1] range. Returns 0 on success or a negative error code.
GL_API int32_t gl_set_process_volume(uint32_t process_id, float volume);

// Restores all sessions changed through gl_set_process_volume.
GL_API int32_t gl_restore_process_volumes(void);

// Plays a PCM WAV file synchronously through the current default output.
GL_API int32_t gl_play_wave(const char* utf8_path);

// Starts/stops the real-time pipeline. Config is a UTF-8 JSON object. Events
// are retrieved using gl_poll_event_json.
GL_API int32_t gl_start(const char* config_json);
GL_API int32_t gl_stop(void);

// Pops one UTF-8 JSON event. Returns 0 when the queue is empty, a positive
// byte count on success/required capacity, or a negative error code.
GL_API int32_t gl_poll_event_json(char* output, int32_t capacity);

// Returns a stable UTF-8 error description for a native error code.
GL_API const char* gl_error_message(int32_t error_code);

#ifdef __cplusplus
}
#endif

#endif  // GAME_LINGO_NATIVE_H_
