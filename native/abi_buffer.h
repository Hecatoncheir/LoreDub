// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// How a string leaves through the C ABI: into the caller's buffer, which is
// asked for again when it was too small.

#pragma once

#include <cstdint>
#include <cstring>
#include <string_view>

// Copies [value] and its terminator into [output] when [capacity] holds
// both, and answers the length either way, so a caller told a larger number
// than it gave knows to ask again with that much room.
inline int32_t WriteString(std::string_view value, char* output, int32_t capacity) {
  const auto required = static_cast<int32_t>(value.size());
  if (output == nullptr || capacity <= required) return required;
  std::memcpy(output, value.data(), value.size());
  output[value.size()] = '\0';
  return required;
}
