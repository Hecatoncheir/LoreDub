// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// What the library has to say, queued until Dart polls for it: one flat
// JSON object per event, as `fromNativeEvent` reads them.

#pragma once

#include <cstdint>
#include <string>
#include <string_view>

// One event, written a field at a time so that no text reaches the queue
// unescaped: `EventJson("state").Text("state", "idle").Push()`.
class EventJson {
 public:
  explicit EventJson(std::string_view type);

  EventJson& Text(std::string_view key, std::string_view value);
  EventJson& Number(std::string_view key, double value);
  EventJson& Flag(std::string_view key, bool value);

  // Closes the object and queues it.
  void Push();

 private:
  void Key(std::string_view key);

  std::string json_;
};

// Hands the oldest event to [output], as WriteString does, and takes it off
// the queue once it fitted. Zero when there is nothing to say.
int32_t PopEvent(char* output, int32_t capacity);

// A failure worded by Windows or by the library, for the banner.
void PushError(std::string_view message);

// What a reader's error becomes: the one Dart can word for itself -- no
// recognizer for [language] -- or the message as it came.
void PushOcrError(std::string_view message, std::string_view language);
