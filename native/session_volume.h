// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// The game turned down while it is dubbed, and given its own volume back.

#pragma once

#include <cstdint>
#include <optional>

// Turns every audio session of [process_id] down to [volume], remembering
// what it was the first time, so the restore puts back the player's own
// volume rather than whatever the dubbing set last. [heard] is set to what
// the process's sound is now multiplied by -- the volume set over the one it
// had -- when a session was turned down at all. Answers 0, or the code of
// the step that could not be taken.
int32_t DuckProcess(uint32_t process_id, float volume, std::optional<double>* heard);

// Gives every session the dubbing turned down its own volume back.
int32_t RestoreDuckedSessions();
