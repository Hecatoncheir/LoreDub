// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// What of the text read off the screen scan after scan is worth handing on:
// pure, tried on its own (native/tests/stable_text_test.cpp).

#ifndef LORE_DUB_STABLE_TEXT_H_
#define LORE_DUB_STABLE_TEXT_H_

#include <chrono>
#include <optional>
#include <string>

// How long the reader waits between two scans of the frame.
inline constexpr std::chrono::milliseconds kOcrScanInterval{650};

// Subtitles are drawn over moving pictures, so one scan reads a line half
// faded in, or a letter of the scenery taken for one of the text. A reading
// is handed on once it came back the same this many scans in a row.
inline constexpr int kScansToTrust = 2;

// Scans that read nothing before the last line handed on is forgotten --
// about four seconds -- so the same line shown again after the frame
// emptied is voiced again, while a subtitle blinking out for a scan or two
// between two lines of one speech is not.
inline constexpr int kEmptyScansToForget = 6;

class StableText {
 public:
  // Takes what one scan read, and answers the text to hand on, if this scan
  // settled one that has not been handed on already.
  std::optional<std::string> Scan(const std::string& text) {
    if (text.empty()) {
      candidate_.clear();
      stable_scans_ = 0;
      if (++empty_scans_ >= kEmptyScansToForget) emitted_.clear();
      return std::nullopt;
    }
    empty_scans_ = 0;
    if (text == candidate_) {
      ++stable_scans_;
    } else {
      candidate_ = text;
      stable_scans_ = 1;
    }
    if (stable_scans_ < kScansToTrust || candidate_ == emitted_) return std::nullopt;
    emitted_ = candidate_;
    return emitted_;
  }

 private:
  std::string candidate_;
  std::string emitted_;
  int stable_scans_ = 0;
  int empty_scans_ = 0;
};

#endif  // LORE_DUB_STABLE_TEXT_H_
