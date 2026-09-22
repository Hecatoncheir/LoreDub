// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

#pragma once

#include <atomic>
#include <cstdint>
#include <functional>
#include <mutex>
#include <string>
#include <thread>

#include "screen_region.h"

// The error either reader reports, as the whole message, when Windows has no
// text recognition for the language asked for.
inline constexpr char kOcrLanguageMissing[] = "ocrLanguageMissing";

// Reads the text inside [area] of the screen once, on the calling thread, in
// [language] (a primary subtag such as "en" or "ru"). An area with no text in
// it is a success with [text] empty; false means OCR could not run, with
// [error] saying why.
bool RecognizeScreenArea(ScreenArea area, const std::string& language, std::string* text,
                         std::string* error);

// Turns a rectangle drawn on the screen into the part of [process_id]'s
// window it covers, each edge a fraction of that window's client area, so a
// frame drawn over a running game means the same thing at another
// resolution. False when the window is nowhere to be found, or the rectangle
// missed it: a frame of nothing would leave the capture reading nothing.
bool RegionOfWindow(uint32_t process_id, ScreenArea area, OcrRegion* region);

// The same for the whole screen: [area] as fractions of the virtual screen,
// every monitor together. False when the rectangle came to nothing.
bool RegionOfScreen(ScreenArea area, OcrRegion* region);

// The other way round: where [region] falls on the screen right now, inside
// [process_id]'s client area -- or on the virtual screen, when that is
// zero. False when the window is nowhere to be found. This is what draws
// the frame over the game, and it measures it the way the reading does.
bool AreaOfRegion(uint32_t process_id, const OcrRegion& region, ScreenArea* area);

// Whether [process_id]'s window is the one in front, which is the only time
// its frame is read -- and so the only time it is worth drawing.
bool WindowIsInFront(uint32_t process_id);

class OcrCapture {
 public:
  using TextCallback = std::function<void(const std::string&)>;
  using ErrorCallback = std::function<void(const std::string&)>;

  OcrCapture();
  ~OcrCapture();

  OcrCapture(const OcrCapture&) = delete;
  OcrCapture& operator=(const OcrCapture&) = delete;

  // [language] is the primary subtag of the text to read, "en" or "ru".
  //
  // [process_id] is the game whose window the frame is read out of, and
  // whose turn in the foreground the reading waits for. Zero reads the
  // virtual screen instead, frame and all, whichever window is in front --
  // which is what a game that keeps no ordinary window needs.
  bool Start(uint32_t process_id, OcrRegion region, std::string language,
             TextCallback on_text, ErrorCallback on_error);
  void Stop();

  // Moves the frame while the capture runs, from the next scan on. The
  // player draws it over the game with a key held, and the reading goes on
  // in the new place rather than being torn down and started again.
  void SetRegion(OcrRegion region);

 private:
  void CaptureThread(uint32_t process_id, std::string language, TextCallback on_text,
                     ErrorCallback on_error);
  OcrRegion Region();

  std::atomic<bool> stopping_{false};
  std::thread thread_;

  // Read by the capture thread on every scan and written by whichever thread
  // the selection ended on.
  std::mutex region_mutex_;
  OcrRegion region_;
};
