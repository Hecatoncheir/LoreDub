// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// Where a phrase of the game's speech begins and ends, out of the packets the
// capture reads. Pure -- no Windows, no clock of its own -- so what decides a
// phrase can be tried without a game, a device or a second of waiting
// (native/tests/phrase_segmenter_test.cpp).

#ifndef LORE_DUB_PHRASE_SEGMENTER_H_
#define LORE_DUB_PHRASE_SEGMENTER_H_

#include <chrono>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <optional>
#include <vector>

namespace capture {

using Clock = std::chrono::steady_clock;

constexpr uint32_t kSampleRate = 16000;

// What is kept ahead of a phrase so its first syllable is not cut off.
constexpr size_t kPreRollSamples = kSampleRate / 4;

// The pause that ends a phrase, in samples of silence heard and in time
// without a voiced packet -- a process that stops rendering delivers no
// packets at all, so the samples alone would leave a phrase open until the
// game speaks again.
constexpr size_t kEndSilenceSamples = kSampleRate * 7 / 10;
constexpr long long kEndSilenceMilliseconds = 700;

// Too short to hold speech: what was caught was a door or a footstep.
constexpr size_t kMinimumSpeechSamples = kSampleRate * 35 / 100;

// A phrase this long is handed on without waiting for the pause.
constexpr size_t kMaximumSegmentSamples = kSampleRate * 12;

// As long as a held take may run. A recording nobody stopped is a mistake
// rather than a wish, and three minutes of one voice says more than a
// fingerprint has any use for.
constexpr size_t kHeldTakeSamples = kSampleRate * 180;

// The loudness a packet must reach to count as speech, at the game's own
// volume; the capture scales it by what the game has been turned down to.
constexpr double kSpeechRms = 180.0;

// The loudness of one packet, as the root mean square of its samples. A
// packet marked silent carries no samples worth reading.
inline double PacketRms(const int16_t* input, size_t frames, bool silent) {
  if (frames == 0 || silent) return 0;
  double square_sum = 0;
  for (size_t index = 0; index < frames; ++index) {
    const double value = input[index];
    square_sum += value * value;
  }
  return std::sqrt(square_sum / static_cast<double>(frames));
}

class PhraseSegmenter {
 public:
  // Takes one packet the capture read: [voiced] is whether it held speech,
  // [now] when it was read.
  void Feed(const int16_t* input, size_t frames, bool silent, bool voiced, Clock::time_point now) {
    if (voiced) last_voice_ = now;
    if (speaking_) {
      Append(input, frames, silent);
      silence_samples_ = voiced ? 0 : silence_samples_ + frames;
      return;
    }
    for (size_t index = 0; index < frames; ++index) pre_roll_.push_back(silent ? 0 : input[index]);
    while (pre_roll_.size() > kPreRollSamples) pre_roll_.pop_front();
    // A phrase begins with what was heard just before it.
    if (voiced) {
      speaking_ = true;
      segment_.assign(pre_roll_.begin(), pre_roll_.end());
      pre_roll_.clear();
    }
  }

  // Asked once a wake-up, after its packets: the phrase that has just ended,
  // if one has and it is long enough to hold speech. While [holding] -- a
  // card recording its take -- neither a pause nor the length of a phrase
  // closes it; letting go does, or the three-minute ceiling.
  std::optional<std::vector<int16_t>> Finish(bool holding, Clock::time_point now) {
    const auto quiet =
        std::chrono::duration_cast<std::chrono::milliseconds>(now - last_voice_).count();
    const bool released = was_holding_ && !holding;
    was_holding_ = holding;
    const bool phrase_over = silence_samples_ >= kEndSilenceSamples ||
                             segment_.size() >= kMaximumSegmentSamples ||
                             quiet >= kEndSilenceMilliseconds;
    const bool take_over = released || segment_.size() >= kHeldTakeSamples;
    if (!speaking_ || !(holding ? take_over : (released || phrase_over))) return std::nullopt;
    std::vector<int16_t> finished = std::move(segment_);
    segment_.clear();
    silence_samples_ = 0;
    speaking_ = false;
    if (finished.size() < kMinimumSpeechSamples) return std::nullopt;
    return finished;
  }

  // What a take has gathered so far, so the caller can tell a recording
  // worth waiting for from a silence worth nothing.
  size_t Gathered() const { return speaking_ ? segment_.size() : 0; }

 private:
  void Append(const int16_t* input, size_t frames, bool silent) {
    const size_t old_size = segment_.size();
    segment_.resize(old_size + frames, 0);
    if (!silent) {
      for (size_t index = 0; index < frames; ++index) segment_[old_size + index] = input[index];
    }
  }

  std::deque<int16_t> pre_roll_;
  std::vector<int16_t> segment_;
  size_t silence_samples_ = 0;
  bool speaking_ = false;
  bool was_holding_ = false;
  Clock::time_point last_voice_ = Clock::now();
};

}  // namespace capture

#endif  // LORE_DUB_PHRASE_SEGMENTER_H_
