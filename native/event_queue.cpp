// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

#include "event_queue.h"

#include "abi_buffer.h"
#include "flat_json.h"
#include "ocr_capture.h"

#include <deque>
#include <mutex>

namespace {

// As many events as a poll every 80 ms could fall behind by; past that the
// oldest go, a stalled interface being no reason to hold memory for ever.
constexpr size_t kEventsKept = 128;

std::mutex event_mutex;
std::deque<std::string> events;

void Queue(std::string event) {
  std::lock_guard<std::mutex> lock(event_mutex);
  if (events.size() >= kEventsKept) events.pop_front();
  events.push_back(std::move(event));
}

}  // namespace

EventJson::EventJson(std::string_view type) {
  json_ = "{\"type\":\"";
  json_ += flat_json::Escape(type);
  json_ += '"';
}

void EventJson::Key(std::string_view key) {
  json_ += ",\"";
  json_ += key;
  json_ += "\":";
}

EventJson& EventJson::Text(std::string_view key, std::string_view value) {
  Key(key);
  json_ += '"';
  json_ += flat_json::Escape(value);
  json_ += '"';
  return *this;
}

EventJson& EventJson::Number(std::string_view key, double value) {
  Key(key);
  json_ += flat_json::Number(value);
  return *this;
}

EventJson& EventJson::Flag(std::string_view key, bool value) {
  Key(key);
  json_ += value ? "true" : "false";
  return *this;
}

void EventJson::Push() {
  json_ += '}';
  Queue(std::move(json_));
  json_.clear();
}

int32_t PopEvent(char* output, int32_t capacity) {
  std::lock_guard<std::mutex> lock(event_mutex);
  if (events.empty()) return 0;
  const int32_t result = WriteString(events.front(), output, capacity);
  if (output != nullptr && capacity > result) events.pop_front();
  return result;
}

void PushError(std::string_view message) { EventJson("error").Text("message", message).Push(); }

void PushOcrError(std::string_view message, std::string_view language) {
  if (message == kOcrLanguageMissing) {
    EventJson("ocrLanguageMissing").Text("language", language).Push();
  } else {
    PushError(message);
  }
}
