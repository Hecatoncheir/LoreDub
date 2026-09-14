// Copyright (c) 2026 LoreDub contributors.
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

  bool Start(uint32_t process_id, bool exclude_process_tree,
             std::wstring output_directory,
             SegmentCallback on_segment, ErrorCallback on_error);
  void Stop();

  // How far the captured process has been turned down by the caller, as a
  // factor of the volume it had. Windows takes the loopback tap after the
  // session volume, so without this the speech threshold grows stricter the
  // quieter the game is put: at a fifth of the volume a fifth of the voices
  // in a game stop counting as speech. The threshold follows the factor, so
  // the same phrases are heard whatever the game is turned down to — and a
  // change made in the middle of a phrase does not read as its end.
  void SetSpeechAttenuation(double factor);

  // Holds the recording open: while set, what is captured is one take,
  // ended by nothing but this being cleared. The card being recorded on the
  // characters screen wants everything the player heard between pressing
  // record and pressing stop -- a phrase cut at twelve seconds is a phrase
  // the game happened to be playing music over.
  void SetHoldingTake(bool holding);

  // How much of a take is gathered right now, in samples. Zero means the
  // game has said nothing since the take was opened, so letting go of it
  // will deliver no recording and nobody should wait for one.
  size_t HeldSamples() const;

 private:
  void CaptureThread(uint32_t process_id, bool exclude_process_tree,
                     std::wstring output_directory,
                     SegmentCallback on_segment, ErrorCallback on_error);

  std::atomic<bool> stopping_{false};
  std::atomic<bool> holding_{false};
  std::atomic<size_t> held_samples_{0};
  std::atomic<double> attenuation_{1.0};
  std::thread thread_;
};
