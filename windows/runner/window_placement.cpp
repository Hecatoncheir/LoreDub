// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

#include "window_placement.h"

namespace {

// The registry rather than a file beside the settings: the frame is wanted
// before CreateWindow, which is before Flutter -- and with it everything that
// reads and writes the application's own files -- exists. The installer drops
// the key on uninstall.
constexpr const wchar_t kWindowRegKey[] = L"Software\\LoreDub\\Window";
constexpr const wchar_t kLeftValue[] = L"Left";
constexpr const wchar_t kTopValue[] = L"Top";
constexpr const wchar_t kWidthValue[] = L"Width";
constexpr const wchar_t kHeightValue[] = L"Height";
constexpr const wchar_t kMaximizedValue[] = L"Maximized";

bool ReadValue(const wchar_t* name, DWORD* value) {
  DWORD size = sizeof(DWORD);
  return RegGetValue(HKEY_CURRENT_USER, kWindowRegKey, name, RRF_RT_REG_DWORD,
                     nullptr, value, &size) == ERROR_SUCCESS;
}

void WriteValue(HKEY key, const wchar_t* name, DWORD value) {
  RegSetValueEx(key, name, 0, REG_DWORD, reinterpret_cast<const BYTE*>(&value),
                sizeof(value));
}

// WINDOWPLACEMENT speaks workspace coordinates, whose origin is the top left
// of the primary monitor's work area; CreateWindow speaks screen coordinates.
// The two differ only where the taskbar sits at the top or the left of that
// monitor -- and there a frame saved and restored without the conversion would
// creep by the height of the taskbar on every start.
POINT WorkspaceOrigin() {
  RECT work = {};
  if (SystemParametersInfo(SPI_GETWORKAREA, 0, &work, 0)) {
    return POINT{work.left, work.top};
  }
  return POINT{0, 0};
}

}  // namespace

std::optional<WindowFrame> LoadWindowFrame() {
  DWORD left = 0;
  DWORD top = 0;
  DWORD width = 0;
  DWORD height = 0;
  DWORD maximized = 0;
  if (!ReadValue(kLeftValue, &left) || !ReadValue(kTopValue, &top) ||
      !ReadValue(kWidthValue, &width) || !ReadValue(kHeightValue, &height)) {
    return std::nullopt;
  }
  ReadValue(kMaximizedValue, &maximized);

  WindowFrame frame = {};
  frame.bounds.left = static_cast<LONG>(left);
  frame.bounds.top = static_cast<LONG>(top);
  frame.bounds.right = frame.bounds.left + static_cast<LONG>(width);
  frame.bounds.bottom = frame.bounds.top + static_cast<LONG>(height);
  frame.maximized = maximized != 0;

  if (width == 0 || height == 0) {
    return std::nullopt;
  }
  if (MonitorFromRect(&frame.bounds, MONITOR_DEFAULTTONULL) == nullptr) {
    return std::nullopt;
  }
  return frame;
}

void SaveWindowFrame(HWND window) {
  WINDOWPLACEMENT placement = {};
  placement.length = sizeof(placement);
  if (!GetWindowPlacement(window, &placement)) {
    return;
  }

  const bool maximized =
      placement.showCmd == SW_SHOWMAXIMIZED ||
      (placement.showCmd == SW_SHOWMINIMIZED &&
       (placement.flags & WPF_RESTORETOMAXIMIZED) != 0);

  RECT bounds = placement.rcNormalPosition;
  const POINT origin = WorkspaceOrigin();
  OffsetRect(&bounds, origin.x, origin.y);

  HKEY key = nullptr;
  if (RegCreateKeyEx(HKEY_CURRENT_USER, kWindowRegKey, 0, nullptr,
                     REG_OPTION_NON_VOLATILE, KEY_SET_VALUE, nullptr, &key,
                     nullptr) != ERROR_SUCCESS) {
    return;
  }
  WriteValue(key, kLeftValue, static_cast<DWORD>(bounds.left));
  WriteValue(key, kTopValue, static_cast<DWORD>(bounds.top));
  WriteValue(key, kWidthValue, static_cast<DWORD>(bounds.right - bounds.left));
  WriteValue(key, kHeightValue,
             static_cast<DWORD>(bounds.bottom - bounds.top));
  WriteValue(key, kMaximizedValue, maximized ? 1 : 0);
  RegCloseKey(key);
}
