// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

#include "process_list.h"

#include "flat_json.h"
#include "text_encoding.h"

#include <windows.h>
#include <tlhelp32.h>

#include <sstream>

namespace {

std::wstring ProcessPath(DWORD process_id) {
  HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, process_id);
  if (process == nullptr) return {};
  std::wstring path(32768, L'\0');
  DWORD length = static_cast<DWORD>(path.size());
  const BOOL read = QueryFullProcessImageNameW(process, 0, path.data(), &length);
  CloseHandle(process);
  if (!read) return {};
  path.resize(length);
  return path;
}

// When Windows started the process, in milliseconds since the Unix epoch, or
// 0 when it will not say: a process of another user, or one that ended
// between the snapshot and this question.
uint64_t ProcessStartedAt(DWORD process_id) {
  HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, process_id);
  if (process == nullptr) return 0;
  FILETIME created{};
  FILETIME exited{};
  FILETIME kernel{};
  FILETIME user{};
  const BOOL read = GetProcessTimes(process, &created, &exited, &kernel, &user);
  CloseHandle(process);
  if (!read) return 0;
  ULARGE_INTEGER ticks{};
  ticks.LowPart = created.dwLowDateTime;
  ticks.HighPart = created.dwHighDateTime;
  // FILETIME counts 100-nanosecond intervals from 1601; the Unix epoch is
  // 11644473600 seconds later.
  constexpr uint64_t epoch_difference = 116444736000000000ULL;
  if (ticks.QuadPart < epoch_difference) return 0;
  return (ticks.QuadPart - epoch_difference) / 10000;
}

std::wstring BaseName(const std::wstring& path) {
  const auto separator = path.find_last_of(L"\\/");
  return separator == std::wstring::npos ? path : path.substr(separator + 1);
}

}  // namespace

std::string ListProcesses() {
  HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snapshot == INVALID_HANDLE_VALUE) return "[]";
  PROCESSENTRY32W entry{};
  entry.dwSize = sizeof(entry);
  std::ostringstream out;
  out << '[';
  bool first = true;
  if (Process32FirstW(snapshot, &entry)) {
    do {
      const std::wstring path = ProcessPath(entry.th32ProcessID);
      if (path.empty()) continue;
      if (!first) out << ',';
      first = false;
      out << "{\"pid\":" << entry.th32ProcessID << ",\"name\":\""
          << flat_json::Escape(encoding::Utf8(BaseName(path))) << "\",\"path\":\""
          << flat_json::Escape(encoding::Utf8(path)) << "\",\"startedAt\":"
          << ProcessStartedAt(entry.th32ProcessID) << '}';
    } while (Process32NextW(snapshot, &entry));
  }
  CloseHandle(snapshot);
  out << ']';
  return out.str();
}
