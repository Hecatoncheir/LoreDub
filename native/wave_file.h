// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

#pragma once

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <string>
#include <vector>

// One place for the shape every recording the pipeline measures is written
// in: 16-bit PCM, one channel, and the same loudness. The fingerprint of a
// voice moves with the level it was heard at, so a file dropped onto a card
// has to be written the way a captured segment is, or the two would not
// answer for the same character.
namespace wave_file {

// The peak a written recording is lifted to, and how far it may be lifted.
// Eight is enough to bring a quiet line up without dragging the room noise
// of a silent one with it.
inline constexpr double kPeak = 28000.0;
inline constexpr double kLoudestGain = 8.0;

inline bool WriteMono(const std::wstring& filename, std::vector<int16_t> samples,
                      uint32_t sample_rate) {
  if (samples.empty()) return false;
  int peak = 1;
  // Parenthesised, so a windows.h included ahead of this header cannot
  // take the calls for its own min and max macros.
  for (const int16_t sample : samples) {
    peak = (std::max)(peak, std::abs(static_cast<int>(sample)));
  }
  const double gain = (std::min)(kLoudestGain, kPeak / static_cast<double>(peak));
  for (int16_t& sample : samples) {
    sample = static_cast<int16_t>(std::clamp(std::lround(sample * gain), -32768L, 32767L));
  }

  std::ofstream output(filename, std::ios::binary);
  if (!output) return false;
  constexpr uint16_t kChannels = 1;
  constexpr uint16_t kBitsPerSample = 16;
  const uint32_t data_size = static_cast<uint32_t>(samples.size() * sizeof(int16_t));
  const uint32_t riff_size = 36 + data_size;
  const uint32_t byte_rate = sample_rate * kChannels * kBitsPerSample / 8;
  const uint16_t block_align = kChannels * kBitsPerSample / 8;
  const uint32_t fmt_size = 16;
  const uint16_t pcm = 1;
  output.write("RIFF", 4);
  output.write(reinterpret_cast<const char*>(&riff_size), sizeof(riff_size));
  output.write("WAVEfmt ", 8);
  output.write(reinterpret_cast<const char*>(&fmt_size), sizeof(fmt_size));
  output.write(reinterpret_cast<const char*>(&pcm), sizeof(pcm));
  output.write(reinterpret_cast<const char*>(&kChannels), sizeof(kChannels));
  output.write(reinterpret_cast<const char*>(&sample_rate), sizeof(sample_rate));
  output.write(reinterpret_cast<const char*>(&byte_rate), sizeof(byte_rate));
  output.write(reinterpret_cast<const char*>(&block_align), sizeof(block_align));
  output.write(reinterpret_cast<const char*>(&kBitsPerSample), sizeof(kBitsPerSample));
  output.write("data", 4);
  output.write(reinterpret_cast<const char*>(&data_size), sizeof(data_size));
  output.write(reinterpret_cast<const char*>(samples.data()), data_size);
  return output.good();
}

}  // namespace wave_file
