// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

#pragma once

#include <cstdint>
#include <functional>

#include "ocr_capture.h"

enum class SelectionResult { selected, cancelled, quit };

// Lets the player draw a rectangle over the whole screen while the key with
// virtual-key code [key] is held, and hands it back in screen pixels once the
// key comes up. A shade dims the screen meanwhile and an orange frame follows
// the mouse; Esc, a right click, or letting go before anything was drawn
// cancels.
//
// Runs a message loop of its own on the calling thread, which must be the
// thread the hotkey arrived on: Windows lets that one take the foreground,
// which is what releases a game's hold on the mouse. Other hotkeys arriving
// meanwhile go to [on_hotkey]; a WM_QUIT ends the selection with
// SelectionResult::quit, and the caller's own loop has to end too.
SelectionResult SelectScreenArea(uint32_t key, ScreenArea* area,
                                 const std::function<void(uintptr_t hotkey_id)>& on_hotkey);
