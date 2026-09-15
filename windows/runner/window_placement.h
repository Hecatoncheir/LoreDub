// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

#ifndef RUNNER_WINDOW_PLACEMENT_H_
#define RUNNER_WINDOW_PLACEMENT_H_

#include <windows.h>

#include <optional>

// Where the main window stood the last time it was closed.
struct WindowFrame {
  // The restored bounds in screen coordinates and physical pixels, i.e. what
  // CreateWindow takes -- never the bounds a maximized window covers.
  RECT bounds;

  // Whether the window was maximized.
  bool maximized;
};

// Reads the frame written by |SaveWindowFrame|. Answers nothing when no frame
// was ever saved, when what was saved is unreadable or empty, or when no
// monitor holds it any more: a window put back onto a display that has since
// been unplugged would open where nobody can reach it.
std::optional<WindowFrame> LoadWindowFrame();

// Writes |window|'s restored frame, so the next start opens it the size the
// player left it at. A minimized window is saved by the frame it would restore
// to -- an application that opens minimized has remembered nothing.
void SaveWindowFrame(HWND window);

#endif  // RUNNER_WINDOW_PLACEMENT_H_
