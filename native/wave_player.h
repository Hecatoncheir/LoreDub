// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// The dubbing's own voice, played a clip at a time.

#pragma once

#include <cstdint>
#include <string>

// Plays the PCM WAV file at [path] and blocks until it has played, as
// PlaySound with SND_SYNC did. PlaySound holds one sound per process and
// cuts off whatever is playing, so two characters could never be heard at
// once; every call here opens a waveOut stream of its own instead, and
// Windows mixes the ones that overlap. Answers 0, -21 when the file could
// not be played, or -22 when the device stopped answering mid-clip.
int32_t PlayWave(const std::wstring& path);

// Ends whatever is sounding, and answers how many clips that was.
int32_t StopWaves();
