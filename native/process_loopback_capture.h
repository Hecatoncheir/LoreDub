// Copyright (c) 2026 GameLingo contributors.
// SPDX-License-Identifier: MIT

#pragma once

#include <atomic>
#include <cstdint>
#include <functional>
#include <memory>
#include <string>
#include <thread>

class ProcessLoopbackCapture {
 public:
  using SegmentCallback = std::function<void(const std::string&)>;
  using ErrorCallback = std::function<void(const std::string&)>;

  ProcessLoopbackCapture();
  ~ProcessLoopbackCapture();

  ProcessLoopbackCapture(const ProcessLoopbackCapture&) = delete;
  ProcessLoopbackCapture& operator=(const ProcessLoopbackCapture&) = delete;

  bool Start(uint32_t process_id, std::wstring output_directory,
             SegmentCallback on_segment, ErrorCallback on_error);
  void Stop();

 private:
  void CaptureThread(uint32_t process_id, std::wstring output_directory,
                     SegmentCallback on_segment, ErrorCallback on_error);

  std::atomic<bool> stopping_{false};
  std::thread thread_;
};
