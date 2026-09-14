// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

#pragma once

#include <atomic>
#include <cstdint>
#include <functional>
#include <mutex>
#include <string>
#include <thread>

// The part of the game window's client area to read, each edge a fraction of
// its width or height from the top-left corner.
struct OcrRegion {
  double left = 0.0;
  double top = 0.55;
  double right = 1.0;
  double bottom = 1.0;
};

// A rectangle of the screen in physical pixels, right and bottom exclusive.
struct ScreenArea {
  int left = 0;
  int top = 0;
  int right = 0;
  int bottom = 0;
};

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

class OcrCapture {
 public:
  using TextCallback = std::function<void(const std::string&)>;
  using ErrorCallback = std::function<void(const std::string&)>;

  OcrCapture();
  ~OcrCapture();

  OcrCapture(const OcrCapture&) = delete;
  OcrCapture& operator=(const OcrCapture&) = delete;

  // [language] is the primary subtag of the text to read, "en" or "ru".
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
