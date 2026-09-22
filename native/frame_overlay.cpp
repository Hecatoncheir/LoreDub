// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

#include "frame_overlay.h"

#include <windows.h>

namespace {

constexpr wchar_t kOverlayClass[] = L"LoreDubFrameOverlay";

// The frame is painted in the orange the interface marks a choice with, and
// everything inside it in a colour the window is made see-through by.
constexpr COLORREF kFrameColor = RGB(255, 74, 22);
constexpr COLORREF kSeeThrough = RGB(0, 0, 0);
constexpr int kFrameWidth = 2;

// How often the frame catches up with the window it follows. Often enough
// that a window dragged across the desktop takes the frame with it, seldom
// enough to be nothing on a frame of the game.
constexpr UINT kFollowMs = 120;
constexpr UINT_PTR kFollowTimer = 1;

LRESULT CALLBACK OverlayProc(HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
  switch (message) {
    case WM_ERASEBKGND:
      return 1;
    // The frame is not a thing to click: every hit goes to the game under it.
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

HINSTANCE ThisModule() {
  HMODULE module = nullptr;
  GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                         GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                     reinterpret_cast<LPCWSTR>(&OverlayProc), &module);
  return static_cast<HINSTANCE>(module);
}

}  // namespace

FrameOverlay::~FrameOverlay() { Hide(); }

bool FrameOverlay::Show(uint32_t process_id, OcrRegion region) {
  {
    std::lock_guard<std::mutex> lock(place_mutex_);
    process_id_ = process_id;
    region_ = region;
  }
  if (thread_.joinable()) return true;
  stopping_ = false;
  thread_ = std::thread(&FrameOverlay::OverlayThread, this);
  return true;
}

void FrameOverlay::Hide() {
  if (!thread_.joinable()) return;
  stopping_ = true;
  // The thread owns the window, and a window may only be destroyed by the
  // thread that made it: it is asked to end its own loop.
  PostThreadMessageW(thread_id_.load(), WM_QUIT, 0, 0);
  thread_.join();
  thread_id_ = 0;
}

void FrameOverlay::OverlayThread() {
  MSG message;
  // Creates this thread's message queue, so a WM_QUIT posted from the
  // outside cannot arrive before there is a queue to receive it.
  PeekMessageW(&message, nullptr, WM_USER, WM_USER, PM_NOREMOVE);
  thread_id_ = GetCurrentThreadId();
  const HINSTANCE module = ThisModule();
  WNDCLASSEXW window_class{};
  window_class.cbSize = sizeof(window_class);
  window_class.lpfnWndProc = OverlayProc;
  window_class.hInstance = module;
  window_class.lpszClassName = kOverlayClass;
  if (RegisterClassExW(&window_class) == 0 && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
    return;
  }
  const HWND window = CreateWindowExW(
      WS_EX_TOPMOST | WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
      kOverlayClass, L"LoreDub", WS_POPUP, 0, 0, 1, 1, nullptr, nullptr, module, nullptr);
  if (window == nullptr) return;
  SetLayeredWindowAttributes(window, kSeeThrough, 0, LWA_COLORKEY);
  SetTimer(window, kFollowTimer, kFollowMs, nullptr);
  Follow(window);
  while (!stopping_ && GetMessageW(&message, nullptr, 0, 0) > 0) {
    if (message.message == WM_TIMER && message.wParam == kFollowTimer) {
      Follow(window);
      continue;
    }
    TranslateMessage(&message);
    DispatchMessageW(&message);
  }
  KillTimer(window, kFollowTimer);
  DestroyWindow(window);
}

void FrameOverlay::Follow(void* window) {
  const HWND overlay = static_cast<HWND>(window);
  uint32_t process_id = 0;
  OcrRegion region;
  {
    std::lock_guard<std::mutex> lock(place_mutex_);
    process_id = process_id_;
    region = region_;
  }
  ScreenArea area{};
  // Over a window the frame means that window's own client area, so it is
  // shown while that window is the one in front and hidden the moment
  // anything else is -- the reading waits for the same thing.
  const bool showing = (process_id == 0 || WindowIsInFront(process_id)) &&
                       AreaOfRegion(process_id, region, &area);
  if (!showing) {
    ShowWindow(overlay, SW_HIDE);
    return;
  }
  SetWindowPos(overlay, HWND_TOPMOST, area.left, area.top, area.right - area.left,
               area.bottom - area.top, SWP_NOACTIVATE);
  if (!IsWindowVisible(overlay)) ShowWindow(overlay, SW_SHOWNOACTIVATE);
  InvalidateRect(overlay, nullptr, TRUE);
}

