// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

#pragma once

#include <atomic>
#include <cstdint>
#include <mutex>
#include <thread>

#include "ocr_capture.h"

// The subtitle frame drawn over the running game, so the player can see
// where their words are being read from without stopping to look at a
// picture of it in LoreDub.
//
// It is a click-through window of its own, always on top and never taking
// the focus, that follows the game's client area; over a window it is shown
// only while that window is the one in front, which is the only time the
// reading looks at it either. Reading the whole screen it is always shown.
class FrameOverlay {
 public:
  FrameOverlay() = default;
  ~FrameOverlay();

  FrameOverlay(const FrameOverlay&) = delete;
  FrameOverlay& operator=(const FrameOverlay&) = delete;

  // Shows the frame over [process_id]'s window, or over the whole screen
  // when that is zero. Called again with another region or another game, it
  // moves rather than being torn down.
  bool Show(uint32_t process_id, OcrRegion region);

  void Hide();

 private:
  void OverlayThread();
  void Follow(void* window);

  std::thread thread_;
  std::atomic<uint32_t> thread_id_{0};
  std::atomic<bool> stopping_{false};

  // Read by the overlay thread on every step and written by whoever moves
  // the frame.
  std::mutex place_mutex_;
  uint32_t process_id_ = 0;
  OcrRegion region_;
};
