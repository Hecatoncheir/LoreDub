// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

#pragma once

#include <atomic>
#include <cstdint>
#include <functional>
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

class OcrCapture {
 public:
  using TextCallback = std::function<void(const std::string&)>;
  using ErrorCallback = std::function<void(const std::string&)>;

  OcrCapture();
  ~OcrCapture();

  OcrCapture(const OcrCapture&) = delete;
  OcrCapture& operator=(const OcrCapture&) = delete;

  bool Start(uint32_t process_id, OcrRegion region, TextCallback on_text,
             ErrorCallback on_error);
  void Stop();

 private:
  void CaptureThread(uint32_t process_id, OcrRegion region,
                     TextCallback on_text, ErrorCallback on_error);

  std::atomic<bool> stopping_{false};
  std::thread thread_;
};
