// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

#include "snapshot_overlay.h"

#if defined(_WIN32)

#define NOMINMAX
#include <windows.h>
#include <windowsx.h>

#include <algorithm>

namespace {

constexpr wchar_t kShadeClass[] = L"LoreDubSnapshotShade";
constexpr wchar_t kFrameClass[] = L"LoreDubSnapshotFrame";

// The accent of the interface, so the frame reads as LoreDub's own.
constexpr COLORREF kFrameColor = RGB(0xFF, 0x4A, 0x16);

// Painted inside the frame, where its window shows what lies under it.
constexpr COLORREF kSeeThrough = RGB(0xFF, 0x00, 0xFF);
constexpr int kFrameWidth = 3;

// How dark the shade is, out of 255: enough to say the screen is being
// selected, little enough to keep the text under it readable.
constexpr BYTE kShadeAlpha = 90;
// IDC_CROSS spelled wide: the build does not define UNICODE, so the macro
// itself names the narrow resource.
const LPCWSTR kCrossCursor = MAKEINTRESOURCEW(32515);
constexpr UINT_PTR kKeyTimer = 1;
constexpr UINT kKeyPollMs = 15;

// A selection nobody finishes gives the screen back after this long.
constexpr ULONGLONG kGiveUpAfterMs = 120000;

// The smallest side worth reading, in pixels.
constexpr int kMinimumSide = 8;

struct Selection {
  uint32_t key = 0;
  POINT origin{};
  HWND frame = nullptr;
  POINT anchor{};
  RECT area{};
  ULONGLONG started = 0;
  bool dragging = false;
  bool has_area = false;
  bool done = false;
  bool cancelled = false;
};

// One selection at a time, on the thread that runs it.
Selection* current = nullptr;

HINSTANCE ThisModule() {
  HMODULE module = nullptr;
  GetModuleHandleExW(
      GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
      reinterpret_cast<LPCWSTR>(&ThisModule), &module);
  return module;
}

POINT ScreenPoint(LPARAM lparam) {
  return POINT{GET_X_LPARAM(lparam) + current->origin.x, GET_Y_LPARAM(lparam) + current->origin.y};
}

void Finish(bool cancelled) {
  current->cancelled = cancelled;
  current->done = true;
}

// Stretches the area from the anchor to [point] and moves the frame with it.
void Follow(POINT point) {
  Selection& selection = *current;
  selection.area = RECT{std::min(selection.anchor.x, point.x), std::min(selection.anchor.y, point.y),
                        std::max(selection.anchor.x, point.x), std::max(selection.anchor.y, point.y)};
  const int width = selection.area.right - selection.area.left;
  const int height = selection.area.bottom - selection.area.top;
  selection.has_area = width >= kMinimumSide && height >= kMinimumSide;
  if (!selection.has_area) {
    ShowWindow(selection.frame, SW_HIDE);
    return;
  }
  // Just outside the area, so the frame never covers the text it encloses.
  SetWindowPos(selection.frame, HWND_TOPMOST, selection.area.left - kFrameWidth,
               selection.area.top - kFrameWidth, width + 2 * kFrameWidth,
               height + 2 * kFrameWidth, SWP_NOACTIVATE | SWP_SHOWWINDOW);
  InvalidateRect(selection.frame, nullptr, FALSE);
}

LRESULT CALLBACK ShadeProc(HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
  if (current == nullptr) return DefWindowProcW(window, message, wparam, lparam);
  switch (message) {
    case WM_SETCURSOR:
      SetCursor(LoadCursorW(nullptr, kCrossCursor));
      return TRUE;
    case WM_ERASEBKGND:
      return 1;
    case WM_PAINT: {
      PAINTSTRUCT paint;
      HDC dc = BeginPaint(window, &paint);
      FillRect(dc, &paint.rcPaint, static_cast<HBRUSH>(GetStockObject(BLACK_BRUSH)));
      EndPaint(window, &paint);
      return 0;
    }
    case WM_LBUTTONDOWN:
      current->anchor = ScreenPoint(lparam);
      current->dragging = true;
      SetCapture(window);
      Follow(current->anchor);
      return 0;
    case WM_MOUSEMOVE:
      if (current->dragging) Follow(ScreenPoint(lparam));
      return 0;
    case WM_LBUTTONUP:
      if (current->dragging) {
        Follow(ScreenPoint(lparam));
        current->dragging = false;
        ReleaseCapture();
      }
      return 0;
    case WM_CAPTURECHANGED:
      current->dragging = false;
      return 0;
    case WM_RBUTTONDOWN:
    case WM_CLOSE:
      Finish(true);
      return 0;
    // With Alt held, as the default combination has it, keys arrive as
    // system keys.
    case WM_KEYDOWN:
    case WM_SYSKEYDOWN:
      if (wparam == VK_ESCAPE) Finish(true);
      return 0;
    case WM_TIMER:
      if (wparam != kKeyTimer) break;
      // The key is polled rather than waited for: its release can land in
      // any window, the game's included, and never reach this one.
      if ((GetAsyncKeyState(static_cast<int>(current->key)) & 0x8000) == 0) {
        Finish(!current->has_area);
      } else if (GetTickCount64() - current->started > kGiveUpAfterMs) {
        Finish(true);
      }
      return 0;
    default:
      break;
  }
  return DefWindowProcW(window, message, wparam, lparam);
}

LRESULT CALLBACK FrameProc(HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
  switch (message) {
    case WM_ERASEBKGND:
      return 1;
    case WM_NCHITTEST:
      return HTTRANSPARENT;
    case WM_PAINT: {
      PAINTSTRUCT paint;
      HDC dc = BeginPaint(window, &paint);
      RECT client{};
      GetClientRect(window, &client);
      HBRUSH frame = CreateSolidBrush(kFrameColor);
      HBRUSH see_through = CreateSolidBrush(kSeeThrough);
      FillRect(dc, &client, frame);
      const RECT inside{client.left + kFrameWidth, client.top + kFrameWidth,
                        client.right - kFrameWidth, client.bottom - kFrameWidth};
      FillRect(dc, &inside, see_through);
      DeleteObject(see_through);
      DeleteObject(frame);
      EndPaint(window, &paint);
      return 0;
    }
    default:
      break;
  }
  return DefWindowProcW(window, message, wparam, lparam);
}

bool RegisterClass(HINSTANCE module, const wchar_t* name, WNDPROC procedure) {
  WNDCLASSEXW window_class{};
  window_class.cbSize = sizeof(window_class);
  window_class.lpfnWndProc = procedure;
  window_class.hInstance = module;
  window_class.hCursor = LoadCursorW(nullptr, kCrossCursor);
  window_class.lpszClassName = name;
  return RegisterClassExW(&window_class) != 0 || GetLastError() == ERROR_CLASS_ALREADY_EXISTS;
}

}  // namespace

SelectionResult SelectScreenArea(uint32_t key, ScreenArea* area,
                                 const std::function<void(uintptr_t hotkey_id)>& on_hotkey) {
  const HINSTANCE module = ThisModule();
  if (!RegisterClass(module, kShadeClass, ShadeProc) ||
      !RegisterClass(module, kFrameClass, FrameProc)) {
    return SelectionResult::cancelled;
  }
  Selection selection;
  selection.key = key;
  selection.origin =
      POINT{GetSystemMetrics(SM_XVIRTUALSCREEN), GetSystemMetrics(SM_YVIRTUALSCREEN)};
  selection.started = GetTickCount64();
  const HWND previous = GetForegroundWindow();
  // Every monitor at once: the game may not be on the primary one.
  const HWND shade = CreateWindowExW(
      WS_EX_TOPMOST | WS_EX_LAYERED | WS_EX_TOOLWINDOW, kShadeClass, L"LoreDub", WS_POPUP,
      selection.origin.x, selection.origin.y, GetSystemMetrics(SM_CXVIRTUALSCREEN),
      GetSystemMetrics(SM_CYVIRTUALSCREEN), nullptr, nullptr, module, nullptr);
  // Owned by the shade, so it always sits above it; the mouse goes through
  // it to the shade.
  selection.frame =
      shade == nullptr
          ? nullptr
          : CreateWindowExW(WS_EX_TOPMOST | WS_EX_LAYERED | WS_EX_TRANSPARENT |
                                WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
                            kFrameClass, L"", WS_POPUP, 0, 0, 0, 0, shade, nullptr, module,
                            nullptr);
  if (shade == nullptr || selection.frame == nullptr) {
    if (shade != nullptr) DestroyWindow(shade);
    return SelectionResult::cancelled;
  }
  current = &selection;
  SetLayeredWindowAttributes(shade, 0, kShadeAlpha, LWA_ALPHA);
  SetLayeredWindowAttributes(selection.frame, kSeeThrough, 0, LWA_COLORKEY);
  ShowWindow(shade, SW_SHOW);
  SetForegroundWindow(shade);
  SetTimer(shade, kKeyTimer, kKeyPollMs, nullptr);
  bool quit = false;
  MSG message;
  while (!selection.done) {
    if (GetMessageW(&message, nullptr, 0, 0) <= 0) {
      quit = true;
      break;
    }
    if (message.hwnd == nullptr && message.message == WM_HOTKEY) {
      on_hotkey(static_cast<uintptr_t>(message.wParam));
      continue;
    }
    TranslateMessage(&message);
    DispatchMessageW(&message);
  }
  KillTimer(shade, kKeyTimer);
  if (GetCapture() == shade) ReleaseCapture();
  DestroyWindow(selection.frame);
  DestroyWindow(shade);
  current = nullptr;
  // The game gets its window back as it was before the key went down.
  if (previous != nullptr && IsWindow(previous)) SetForegroundWindow(previous);
  if (quit) return SelectionResult::quit;
  if (selection.cancelled || !selection.has_area) return SelectionResult::cancelled;
  *area = ScreenArea{selection.area.left, selection.area.top, selection.area.right,
                     selection.area.bottom};
  return SelectionResult::selected;
}

#else

SelectionResult SelectScreenArea(uint32_t, ScreenArea*, const std::function<void(uintptr_t)>&) {
  return SelectionResult::cancelled;
}

#endif
