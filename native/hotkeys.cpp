// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

#include "hotkeys.h"

#include "event_queue.h"
#include "snapshot_overlay.h"

#include <windows.h>

#include <chrono>

namespace {

constexpr int kPauseHotkey = 1;
constexpr int kResumeHotkey = 2;
constexpr int kSnapshotHotkey = 3;
constexpr int kFrameHotkey = 4;
constexpr int kFrameOverlayHotkey = 5;

// Registers one combination, or says which action another program holds it
// for. A zero key leaves the action unbound.
bool RegisterAction(int id, uint32_t key, uint32_t modifiers, const char* action) {
  if (key == 0) return false;
  if (RegisterHotKey(nullptr, id, modifiers | MOD_NOREPEAT, key)) return true;
  EventJson("hotkeyTaken").Text("action", action).Push();
  return false;
}

void PushHotkeyPress(uintptr_t id) {
  if (id == kPauseHotkey) EventJson("hotkey").Text("action", "pause").Push();
  if (id == kResumeHotkey) EventJson("hotkey").Text("action", "resume").Push();
  // The frame is drawn on the application's say-so, not the key's: it knows
  // whether the player asked for one and over which game.
  if (id == kFrameOverlayHotkey) EventJson("hotkey").Text("action", "frameOverlay").Push();
}

// Lets the player draw the subtitle frame over the running game while the
// frame key is held, and moves [reader] into it once the key comes up. The
// frame goes on being read where it was drawn -- nothing here reads the
// area once -- and the new one reaches the settings as an event.
// Returns false when a WM_QUIT arrived during the selection.
bool DrawSubtitleFrame(uint32_t key, uint32_t process_id, OcrCapture* reader) {
  ScreenArea area;
  const auto result = SelectScreenArea(key, &area, PushHotkeyPress);
  if (result == SelectionResult::quit) return false;
  if (result == SelectionResult::cancelled) return true;
  OcrRegion region;
  // Zero is the screen itself: the frame is then measured against every
  // monitor together rather than against a window.
  const bool found = process_id == 0 ? RegionOfScreen(area, &region)
                                     : RegionOfWindow(process_id, area, &region);
  if (!found) {
    EventJson("subtitleFrame").Flag("failed", true).Push();
    return true;
  }
  // The capture thread reads the frame on every scan, so it is enough to
  // hand it the new one: the session is not torn down and started again.
  if (reader != nullptr) reader->SetRegion(region);
  EventJson("subtitleFrame")
      .Number("left", region.left)
      .Number("top", region.top)
      .Number("right", region.right)
      .Number("bottom", region.bottom)
      .Push();
  return true;
}

}  // namespace

// Lets the player select an area while the snapshot key is held, then reads
// it on a thread of its own, so the keys keep answering meanwhile.
// Returns false when a WM_QUIT arrived during the selection.
bool HotkeyThread::TakeSnapshot(uint32_t key, const std::string& language) {
  ScreenArea area;
  const auto result = SelectScreenArea(key, &area, PushHotkeyPress);
  if (result == SelectionResult::quit) return false;
  if (result == SelectionResult::cancelled) return true;
  if (snapshot_reader_.joinable()) snapshot_reader_.join();
  EventJson("snapshotReading").Push();
  snapshot_reader_ = std::thread([area, language] {
    // The shade has to leave the screen, and a game that lost the
    // foreground to it has to draw itself again, before the area is copied.
    std::this_thread::sleep_for(std::chrono::milliseconds(150));
    std::string text;
    std::string error;
    if (RecognizeScreenArea(area, language, &text, &error)) {
      EventJson("snapshot").Text("text", text).Push();
    } else {
      EventJson("snapshot").Text("text", "").Flag("failed", true).Push();
      PushOcrError(error, language);
    }
  });
  return true;
}

void HotkeyThread::Loop(HotkeyConfig config, std::promise<void>* ready) {
  MSG message;
  // Creates this thread's message queue, so a WM_QUIT posted from the
  // outside cannot arrive before there is a queue to receive it.
  PeekMessageW(&message, nullptr, WM_USER, WM_USER, PM_NOREMOVE);
  thread_id_ = GetCurrentThreadId();
  const bool pause_ok =
      RegisterAction(kPauseHotkey, config.pause_key, config.pause_modifiers, "pause");
  const bool resume_ok =
      RegisterAction(kResumeHotkey, config.resume_key, config.resume_modifiers, "resume");
  const bool snapshot_ok =
      RegisterAction(kSnapshotHotkey, config.snapshot_key, config.snapshot_modifiers, "snapshot");
  const bool frame_ok =
      RegisterAction(kFrameHotkey, config.frame_key, config.frame_modifiers, "frame");
  const bool overlay_ok = RegisterAction(kFrameOverlayHotkey, config.frame_overlay_key,
                                         config.frame_overlay_modifiers, "frameOverlay");
  ready->set_value();
  while (GetMessageW(&message, nullptr, 0, 0) > 0) {
    if (message.message != WM_HOTKEY) continue;
    if (message.wParam == kSnapshotHotkey) {
      if (!TakeSnapshot(config.snapshot_key, config.snapshot_language)) break;
      continue;
    }
    if (message.wParam == kFrameHotkey) {
      if (!DrawSubtitleFrame(config.frame_key, config.frame_process_id,
                             config.subtitle_reader.get())) {
        break;
      }
      continue;
    }
    PushHotkeyPress(static_cast<uintptr_t>(message.wParam));
  }
  if (pause_ok) UnregisterHotKey(nullptr, kPauseHotkey);
  if (resume_ok) UnregisterHotKey(nullptr, kResumeHotkey);
  if (snapshot_ok) UnregisterHotKey(nullptr, kSnapshotHotkey);
  if (frame_ok) UnregisterHotKey(nullptr, kFrameHotkey);
  if (overlay_ok) UnregisterHotKey(nullptr, kFrameOverlayHotkey);
}

void HotkeyThread::Start(HotkeyConfig config) {
  Stop();
  if (!config.BindsAny()) return;
  std::lock_guard<std::mutex> lock(mutex_);
  std::promise<void> ready;
  auto registered = ready.get_future();
  thread_ = std::thread(&HotkeyThread::Loop, this, std::move(config), &ready);
  // The thread holds [ready] only until it has registered.
  registered.wait();
}

void HotkeyThread::Stop() {
  std::lock_guard<std::mutex> lock(mutex_);
  if (!thread_.joinable()) return;
  PostThreadMessageW(thread_id_.load(), WM_QUIT, 0, 0);
  thread_.join();
  thread_id_ = 0;
  if (snapshot_reader_.joinable()) snapshot_reader_.join();
}
