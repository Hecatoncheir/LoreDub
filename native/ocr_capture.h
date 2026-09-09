// Copyright (c) 2026 GameLingo contributors.
// SPDX-License-Identifier: MIT

#pragma once

#include <atomic>
#include <cstdint>
#include <functional>
#include <string>
#include <thread>

class OcrCapture {
 public:
  using TextCallback = std::function<void(const std::string&)>;
  using ErrorCallback = std::function<void(const std::string&)>;

  OcrCapture();
  ~OcrCapture();

  OcrCapture(const OcrCapture&) = delete;
  OcrCapture& operator=(const OcrCapture&) = delete;

  bool Start(uint32_t process_id, double region_top, TextCallback on_text,
             ErrorCallback on_error);
  void Stop();

 private:
  void CaptureThread(uint32_t process_id, double region_top,
                     TextCallback on_text, ErrorCallback on_error);

  std::atomic<bool> stopping_{false};
  std::thread thread_;
};
