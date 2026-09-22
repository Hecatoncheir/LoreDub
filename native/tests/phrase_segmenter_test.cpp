// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// Where the capture decides a phrase begins and ends, tried on packets made
// up here and a clock moved by hand.

#include "phrase_segmenter.h"

#include <cstdio>
#include <cstdlib>
#include <vector>

namespace {

using capture::Clock;
using capture::PhraseSegmenter;

int failures = 0;

void Check(bool holds, const char* what) {
  if (holds) return;
  std::printf("FAILED: %s\n", what);
  ++failures;
}

// Ten milliseconds of audio at 16 kHz.
constexpr size_t kPacket = 160;

struct Feeder {
  PhraseSegmenter segmenter;
  Clock::time_point now = Clock::now();

  void Voice(size_t packets, int16_t value = 1000) {
    const std::vector<int16_t> packet(kPacket, value);
    for (size_t index = 0; index < packets; ++index) {
      now += std::chrono::milliseconds(10);
      segmenter.Feed(packet.data(), kPacket, false, true, now);
    }
  }

  void Quiet(size_t packets, bool silent = false) {
    const std::vector<int16_t> packet(kPacket, 3);
    for (size_t index = 0; index < packets; ++index) {
      now += std::chrono::milliseconds(10);
      segmenter.Feed(packet.data(), kPacket, silent, false, now);
    }
  }

  std::optional<std::vector<int16_t>> Finish(bool holding = false) {
    return segmenter.Finish(holding, now);
  }
};

void PacketLoudness() {
  const std::vector<int16_t> loud(kPacket, 300);
  Check(capture::PacketRms(loud.data(), kPacket, false) == 300.0, "rms of a flat packet");
  Check(capture::PacketRms(loud.data(), kPacket, true) == 0.0, "a silent packet is silence");
  Check(capture::PacketRms(loud.data(), 0, false) == 0.0, "an empty packet is silence");
}

void PhraseEndsOnPause() {
  Feeder feeder;
  feeder.Quiet(10);
  feeder.Voice(100);  // One second of speech.
  Check(!feeder.Finish(), "a phrase still being spoken is not finished");
  feeder.Quiet(69);
  Check(!feeder.Finish(), "a pause shorter than 0.7 s does not end it");
  feeder.Quiet(1);
  const auto phrase = feeder.Finish();
  Check(phrase.has_value(), "0.7 s of quiet ends the phrase");
  // The pre-roll, the speech and the pause.
  Check(phrase && phrase->size() == (10 + 100 + 70) * kPacket, "the phrase keeps its pre-roll");
  Check(phrase && phrase->front() == 3, "the phrase opens with what came before it");
  Check(!feeder.Finish(), "a finished phrase is handed on once");
}

void PreRollIsAQuarterSecond() {
  Feeder feeder;
  feeder.Quiet(100);
  feeder.Voice(40);
  feeder.Quiet(70);
  const auto phrase = feeder.Finish();
  Check(phrase && phrase->size() == capture::kPreRollSamples + (39 + 70) * kPacket,
        "no more than a quarter second is kept ahead of a phrase");
}

void SilentPacketsAreZeroes() {
  Feeder feeder;
  feeder.Voice(40);
  feeder.Quiet(70, true);
  const auto phrase = feeder.Finish();
  Check(phrase && phrase->back() == 0, "a packet marked silent is written as zeroes");
}

void ClockEndsAPhraseWithNoPackets() {
  Feeder feeder;
  feeder.Voice(50);
  // The game stops rendering: nothing arrives, and only time passes.
  feeder.now += std::chrono::milliseconds(699);
  Check(!feeder.Finish(), "under 0.7 s without a packet the phrase stays open");
  feeder.now += std::chrono::milliseconds(1);
  Check(feeder.Finish().has_value(), "0.7 s without a voiced packet ends it");
}

void ShortSoundIsDropped() {
  Feeder feeder;
  feeder.Voice(20);  // 0.2 s: a door, a footstep.
  feeder.Quiet(10);
  feeder.now += std::chrono::milliseconds(700);
  Check(!feeder.Finish(), "under 0.35 s is not speech");
  Check(feeder.segmenter.Gathered() == 0, "and is thrown away");
}

void LongPhraseIsCut() {
  Feeder feeder;
  feeder.Voice(1199);
  Check(!feeder.Finish(), "under twelve seconds the phrase runs on");
  feeder.Voice(1);
  const auto phrase = feeder.Finish();
  Check(phrase && phrase->size() == capture::kMaximumSegmentSamples,
        "twelve seconds of speech are handed on without a pause");
}

void HeldTakeIgnoresPauses() {
  Feeder feeder;
  Check(!feeder.Finish(true), "an empty take is nothing");
  feeder.Voice(50);
  feeder.Quiet(200);
  Check(!feeder.Finish(true), "a pause does not close a held take");
  feeder.Voice(1300);
  Check(!feeder.Finish(true), "nor does the length of a phrase");
  Check(feeder.segmenter.Gathered() == (50 + 200 + 1300) * kPacket, "the take counts what it holds");
  const auto take = feeder.Finish(false);
  Check(take && take->size() == (50 + 200 + 1300) * kPacket, "letting go hands the take on whole");
}

void HeldTakeHasACeiling() {
  Feeder feeder;
  feeder.Finish(true);
  feeder.Voice(18000);
  const auto take = feeder.Finish(true);
  Check(take && take->size() == capture::kHeldTakeSamples, "three minutes close a held take");
}

void ReleasedSilenceIsNothing() {
  Feeder feeder;
  feeder.Finish(true);
  feeder.Quiet(300);
  Check(!feeder.Finish(false), "a take of silence delivers nothing when let go");
}

}  // namespace

int main() {
  PacketLoudness();
  PhraseEndsOnPause();
  PreRollIsAQuarterSecond();
  SilentPacketsAreZeroes();
  ClockEndsAPhraseWithNoPackets();
  ShortSoundIsDropped();
  LongPhraseIsCut();
  HeldTakeIgnoresPauses();
  HeldTakeHasACeiling();
  ReleasedSilenceIsNothing();
  if (failures > 0) return EXIT_FAILURE;
  std::printf("phrase_segmenter: all checks hold\n");
  return EXIT_SUCCESS;
}
