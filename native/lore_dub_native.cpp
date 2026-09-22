// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// The C ABI, and the session it starts and stops. What each call reaches
// lives in a file of its own: the event queue, the process list, the probe
// of the graphics hardware, the sessions' volume, the keys and the player.

#include "lore_dub_native.h"

#include "abi_buffer.h"
#include "audio_decoder.h"
#include "event_queue.h"
#include "flat_json.h"
#include "frame_overlay.h"
#include "graphics_probe.h"
#include "hotkeys.h"
#include "ocr_capture.h"
#include "process_list.h"
#include "process_loopback_capture.h"
#include "session_volume.h"
#include "text_encoding.h"
#include "wave_player.h"

#include <windows.h>

#include <algorithm>
#include <atomic>
#include <memory>
#include <optional>
#include <string>

namespace {

bool running = false;

// Read on the capture threads: while set, what they finish is thrown away
// instead of queued.
std::atomic<bool> paused{false};
std::unique_ptr<ProcessLoopbackCapture> loopback_capture;

// The process the capture is listening to, while it listens to one. Turning
// that process down turns the capture down with it, so the capture is told
// of the change and holds its speech threshold at the same sensitivity.
// Zero while the whole default output is captured: nothing is turned down
// there.
uint32_t captured_process_id = 0;

// Shared with the key thread, which moves the frame it reads.
std::shared_ptr<OcrCapture> ocr_capture;

HotkeyThread hotkeys;

// The frame drawn over the game, which outlives a session: the player asks
// for it on the Screen page and it stays until they say otherwise.
FrameOverlay frame_overlay;

OcrRegion RegionOf(const flat_json::Object& config) {
  return OcrRegion{config.Number("ocrRegionLeft", 0.0), config.Number("ocrRegionTop", 0.55),
                   config.Number("ocrRegionRight", 1.0), config.Number("ocrRegionBottom", 1.0)};
}

// What ld_start was asked for, read once.
struct StartConfig {
  uint32_t process_id = 0;
  std::string capture_directory;
  // Reading the whole screen needs no window, and so no process to find it
  // by -- one may still be named, to be turned down while the reading runs.
  bool whole_screen = false;
  bool reads_screen = false;
  // The screen read while the game is listened to as well: the words come
  // off the frame, and the voice heard as they appeared is what colours
  // them. Neither capture knows about the other.
  bool hears_voices = false;
  // A session that captures nothing at all: the worker is up and the keys
  // are registered, so a snippet the player picks out is read and voiced,
  // and nothing is scanned until they ask. It needs no window and no
  // directory to write segments into.
  bool captures_nothing = false;
  // Everything the default output plays rather than one process.
  bool captures_system = false;
  OcrRegion region;
  std::string ocr_language = "en";

  bool HearsAudio() const { return !captures_nothing && (!reads_screen || hears_voices); }

  // Hearing the voices needs the game itself, whatever the frame is read
  // out of: the sound is taken from that process.
  bool NeedsProcess() const {
    return reads_screen ? (!whole_screen || hears_voices) : (!captures_nothing && !captures_system);
  }

  bool NeedsDirectory() const { return hears_voices || (!reads_screen && !captures_nothing); }
};

StartConfig ParseStartConfig(const char* json) {
  const auto config = flat_json::Object::Parse(json);
  const std::string capture_mode = config.String("captureMode");
  StartConfig start;
  start.process_id = config.Unsigned("processId");
  start.capture_directory = config.String("captureDirectory");
  start.whole_screen = config.String("ocrSource") == "screen";
  start.reads_screen = capture_mode == "ocr" || capture_mode == "ocrAndAudio";
  start.hears_voices = capture_mode == "ocrAndAudio";
  start.captures_nothing = capture_mode == "none";
  start.captures_system = config.String("audioSource") == "system";
  start.region = RegionOf(config);
  if (auto language = config.String("ocrLanguage"); !language.empty()) {
    start.ocr_language = std::move(language);
  }
  return start;
}

bool StartOcrSession(const StartConfig& start) {
  ocr_capture = std::make_shared<OcrCapture>();
  const std::string language = start.ocr_language;
  const bool started = ocr_capture->Start(
      start.whole_screen ? 0 : start.process_id, start.region, language,
      [](const std::string& recognized_text) {
        if (paused) return;
        EventJson("ocrText").Text("text", recognized_text).Push();
      },
      [language](const std::string& message) { PushOcrError(message, language); });
  if (!started) ocr_capture.reset();
  return started;
}

bool StartAudioSession(const StartConfig& start) {
  loopback_capture = std::make_unique<ProcessLoopbackCapture>();
  const uint32_t capture_process_id =
      start.captures_system ? GetCurrentProcessId() : start.process_id;
  // Only a named process is ever turned down; the whole default output is
  // captured as it plays.
  captured_process_id = start.captures_system ? 0 : start.process_id;
  const bool started = loopback_capture->Start(
      capture_process_id, start.captures_system, encoding::Wide(start.capture_directory),
      [](const std::string& filename) {
        // Queued even while paused: the Dart side drops a segment that
        // arrives during the pause and deletes its file, so the native
        // library never deletes files itself.
        EventJson("audioSegment").Text("path", filename).Push();
      },
      [](const std::string& message) { PushError(message); });
  if (!started) {
    loopback_capture.reset();
    captured_process_id = 0;
  }
  return started;
}

}  // namespace

int32_t ld_abi_version(void) { return 1; }

int32_t ld_is_process_loopback_supported(void) { return 1; }

int32_t ld_list_processes_json(char* output, int32_t capacity) {
  return WriteString(ListProcesses(), output, capacity);
}

int32_t ld_list_monitors_json(char* output, int32_t capacity) {
  return WriteString(ListMonitors(), output, capacity);
}

int32_t ld_probe_graphics_json(char* output, int32_t capacity) {
  return WriteString(ProbeGraphics(), output, capacity);
}

int32_t ld_set_process_volume(uint32_t process_id, float volume) {
  std::optional<double> heard;
  const int32_t result = DuckProcess(process_id, std::clamp(volume, 0.0f, 1.0f), &heard);
  // What the capture will hear from now on is this process's own sound
  // times the volume just set.
  if (heard && loopback_capture && process_id == captured_process_id) {
    loopback_capture->SetSpeechAttenuation(*heard);
  }
  return result;
}

int32_t ld_restore_process_volumes(void) {
  const int32_t result = RestoreDuckedSessions();
  // The game is back at its own volume, and so is what the capture hears.
  if (loopback_capture) loopback_capture->SetSpeechAttenuation(1.0);
  return result;
}

int32_t ld_hold_take(int32_t holding) {
  if (!loopback_capture) return -5;
  // What the take had gathered when it was let go of, in milliseconds, so
  // the caller knows whether a recording is on its way. Opening one answers
  // zero: there is nothing in it yet.
  const size_t held = holding != 0 ? 0 : loopback_capture->HeldSamples();
  loopback_capture->SetHoldingTake(holding != 0);
  return static_cast<int32_t>(held * 1000 / 16000);
}

int32_t ld_set_paused(int32_t value) {
  paused = value != 0;
  return 0;
}

int32_t ld_show_frame(const char* config_json) {
  if (config_json == nullptr || config_json[0] == '\0') return -4;
  const auto config = flat_json::Object::Parse(config_json);
  return frame_overlay.Show(config.Unsigned("processId"), RegionOf(config)) ? 0 : -8;
}

int32_t ld_hide_frame(void) {
  frame_overlay.Hide();
  return 0;
}

int32_t ld_set_hotkeys(const char* config_json) {
  if (config_json == nullptr || config_json[0] == '\0') {
    hotkeys.Stop();
    return 0;
  }
  const auto config = flat_json::Object::Parse(config_json);
  HotkeyConfig keys{config.Unsigned("frameOverlayKey"),
                    config.Unsigned("frameOverlayModifiers"),
                    config.Unsigned("pauseKey"),
                    config.Unsigned("pauseModifiers"),
                    config.Unsigned("resumeKey"),
                    config.Unsigned("resumeModifiers"),
                    config.Unsigned("snapshotKey"),
                    config.Unsigned("snapshotModifiers"),
                    config.Unsigned("frameKey"),
                    config.Unsigned("frameModifiers"),
                    config.Unsigned("frameProcessId")};
  if (auto language = config.String("snapshotLanguage"); !language.empty()) {
    keys.snapshot_language = std::move(language);
  }
  keys.subtitle_reader = ocr_capture;
  hotkeys.Start(std::move(keys));
  return 0;
}

int32_t ld_play_wave(const char* utf8_path) {
  if (utf8_path == nullptr || utf8_path[0] == '\0') return -20;
  return PlayWave(encoding::Wide(utf8_path));
}

int32_t ld_stop_wave(void) { return StopWaves(); }

int32_t ld_start(const char* config_json) {
  if (running) return -3;
  if (config_json == nullptr || config_json[0] == '\0') return -4;
  running = true;
  paused = false;
  EventJson("state").Text("state", "starting").Push();
  const StartConfig start = ParseStartConfig(config_json);
  if ((start.NeedsProcess() && start.process_id == 0) ||
      (start.NeedsDirectory() && start.capture_directory.empty())) {
    running = false;
    return -5;
  }
  if (start.reads_screen && !StartOcrSession(start)) {
    running = false;
    return -7;
  }
  if (start.HearsAudio() && !StartAudioSession(start)) {
    if (ocr_capture) {
      ocr_capture->Stop();
      ocr_capture.reset();
    }
    running = false;
    return -6;
  }
  EventJson("state").Text("state", "listening").Push();
  return 0;
}

int32_t ld_stop(void) {
  // The keys belong to the session and go with it. The thread holds its own
  // reference to the reading it moves, so the order below is not what keeps
  // a selection still on screen out of freed memory.
  hotkeys.Stop();
  if (loopback_capture) {
    loopback_capture->Stop();
    loopback_capture.reset();
  }
  captured_process_id = 0;
  if (ocr_capture) {
    ocr_capture->Stop();
    ocr_capture.reset();
  }
  running = false;
  paused = false;
  EventJson("state").Text("state", "idle").Push();
  ld_restore_process_volumes();
  return 0;
}

int32_t ld_poll_event_json(char* output, int32_t capacity) { return PopEvent(output, capacity); }

// A file the player dropped onto a card, brought into the shape every
// other recording the converter is shown comes in. The work is Windows's
// own decoders; what is ours is the rate and the loudness, which is what
// lets a dropped file and a captured line answer for the same character.
int32_t ld_decode_audio(const char* utf8_path, const char* utf8_output_path) {
  if (utf8_path == nullptr || utf8_path[0] == '\0') return -30;
  if (utf8_output_path == nullptr || utf8_output_path[0] == '\0') return -30;
  double seconds = 0;
  const int32_t result =
      DecodeAudioFile(encoding::Wide(utf8_path), encoding::Wide(utf8_output_path), &seconds);
  if (result != 0) {
    // The decoder's own codes sit apart from the pipeline's.
    return result == kDecodeUnsupported ? -31 : (result == kDecodeNoAudio ? -32 : -33);
  }
  return static_cast<int32_t>(seconds * 1000.0);
}

const char* ld_error_message(int32_t error_code) {
  switch (error_code) {
    case 0: return "Success";
    case -2: return "Feature is unsupported on this platform";
    case -3: return "Pipeline is already running";
    case -4: return "Pipeline configuration is empty";
    case -5: return "Pipeline process or capture directory is invalid";
    case -6: return "Cannot start the Windows process loopback worker";
    case -7: return "Cannot start the Windows OCR worker";
    case -8: return "Cannot show the subtitle frame";
    case -10: return "Cannot create Windows audio device enumerator";
    case -11: return "Cannot open the default render endpoint";
    case -12: return "Cannot activate the audio session manager";
    case -13: return "Cannot enumerate audio sessions";
    case -14: return "No matching active audio session was found";
    case -20: return "Playback path is empty";
    case -21: return "Windows could not play the generated wave file";
    case -22: return "The sound device stopped answering while a line played";
    case -30: return "Audio path is empty";
    case -31: return "Windows cannot decode this sound file";
    case -32: return "The file holds no audio";
    case -33: return "The decoded recording could not be written";
    default: return "Unknown native error";
  }
}
