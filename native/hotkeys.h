// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// The keys the player presses inside the game. RegisterHotKey delivers
// WM_HOTKEY to the thread that registered, so the keys live on a thread of
// their own with nothing but a message loop; what they do arrives on the
// event queue.

#pragma once

#include <atomic>
#include <cstdint>
#include <future>
#include <memory>
#include <mutex>
#include <string>
#include <thread>

#include "ocr_capture.h"

struct HotkeyConfig {
  uint32_t frame_overlay_key = 0;
  uint32_t frame_overlay_modifiers = 0;
  uint32_t pause_key = 0;
  uint32_t pause_modifiers = 0;
  uint32_t resume_key = 0;
  uint32_t resume_modifiers = 0;
  uint32_t snapshot_key = 0;
  uint32_t snapshot_modifiers = 0;
  uint32_t frame_key = 0;
  uint32_t frame_modifiers = 0;

  // Whose window the subtitle frame is measured against. The frame is kept
  // in fractions of that window's client area, so there is nothing to
  // measure without it.
  uint32_t frame_process_id = 0;

  // The primary subtag a selected area is read in.
  std::string snapshot_language = "en";

  // The reading a frame drawn with the frame key moves, when the session
  // reads the screen at all. Held here rather than reached for, so a
  // capture let go of by the session is not let go of under a selection
  // still on screen.
  std::shared_ptr<OcrCapture> subtitle_reader;

  // Whether any key is bound at all; a thread for none is not started.
  bool BindsAny() const {
    return pause_key != 0 || resume_key != 0 || snapshot_key != 0 || frame_key != 0 ||
           frame_overlay_key != 0;
  }
};

class HotkeyThread {
 public:
  // Registers [config]'s keys on a thread of its own, and returns once they
  // are registered -- or reported taken by another program.
  void Start(HotkeyConfig config);

  // Lets go of the keys and of the snapshot being read, if one is.
  void Stop();

 private:
  void Loop(HotkeyConfig config, std::promise<void>* ready);
  bool TakeSnapshot(uint32_t key, const std::string& language);

  std::mutex mutex_;
  std::thread thread_;
  std::atomic<unsigned long> thread_id_{0};

  // Reads the area the player selected. Only the key thread starts it, and
  // Stop joins it once that thread is gone.
  std::thread snapshot_reader_;
};
