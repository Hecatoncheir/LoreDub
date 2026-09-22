// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// UTF-8, which is what crosses to Dart, and the UTF-16 Windows speaks. One
// pair of converters for the whole library: there used to be three, each
// counting the terminator its own way.

#pragma once

#include <windows.h>

#include <string>
#include <string_view>

namespace encoding {

inline std::string Utf8(std::wstring_view input) {
  if (input.empty()) return {};
  const int length = static_cast<int>(input.size());
  const int size = WideCharToMultiByte(CP_UTF8, 0, input.data(), length, nullptr, 0, nullptr,
                                       nullptr);
  if (size <= 0) return {};
  std::string output(static_cast<size_t>(size), '\0');
  WideCharToMultiByte(CP_UTF8, 0, input.data(), length, output.data(), size, nullptr, nullptr);
  return output;
}

inline std::wstring Wide(std::string_view input) {
  if (input.empty()) return {};
  const int length = static_cast<int>(input.size());
  const int size = MultiByteToWideChar(CP_UTF8, 0, input.data(), length, nullptr, 0);
  if (size <= 0) return {};
  std::wstring output(static_cast<size_t>(size), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, input.data(), length, output.data(), size);
  return output;
}

}  // namespace encoding
