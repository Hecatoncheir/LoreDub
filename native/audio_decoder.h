// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

#pragma once

#include <cstdint>
#include <string>

// Why a file could not be turned into a recording. The caller writes these
// out; nothing here raises a sentence.
inline constexpr int32_t kDecodeUnavailable = -1;
inline constexpr int32_t kDecodeUnsupported = -2;
inline constexpr int32_t kDecodeNoAudio = -3;
inline constexpr int32_t kDecodeNotWritten = -4;

// Reads any sound file Windows can decode and writes it as the 16 kHz mono
// 16-bit WAV the rest of the pipeline measures voices in, at the loudness a
// captured segment is written at. Returns 0, or one of the codes above.
int32_t DecodeAudioFile(const std::wstring& input, const std::wstring& output, double* seconds);
