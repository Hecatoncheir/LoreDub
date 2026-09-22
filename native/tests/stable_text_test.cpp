// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// Which of the readings a scan after scan of the subtitle frame gives are
// handed on, and which are passed over as half-drawn or already said.

#include "stable_text.h"

#include <cstdio>
#include <cstdlib>

namespace {

int failures = 0;

void Check(bool holds, const char* what) {
  if (holds) return;
  std::printf("FAILED: %s\n", what);
  ++failures;
}

void SettledLineIsHandedOn() {
  StableText reading;
  Check(!reading.Scan("Hello there"), "one scan is not trusted");
  const auto settled = reading.Scan("Hello there");
  Check(settled && *settled == "Hello there", "two alike are handed on");
  Check(!reading.Scan("Hello there"), "and only once");
}

void FlickerIsPassedOver() {
  StableText reading;
  reading.Scan("Hel");
  Check(!reading.Scan("Hello th"), "a line still fading in is not handed on");
  Check(!reading.Scan("Hello there"), "nor the first scan of the line it became");
  Check(reading.Scan("Hello there").has_value(), "the second scan of it is");
}

void NextLineIsHandedOn() {
  StableText reading;
  reading.Scan("One");
  reading.Scan("One");
  reading.Scan("Two");
  const auto settled = reading.Scan("Two");
  Check(settled && *settled == "Two", "the next line is handed on in its turn");
}

void BlinkDoesNotRepeat() {
  StableText reading;
  reading.Scan("Line");
  reading.Scan("Line");
  for (int scan = 0; scan < kEmptyScansToForget - 1; ++scan) reading.Scan("");
  reading.Scan("Line");
  Check(!reading.Scan("Line"), "a line blinking out for a moment is not said twice");
}

void EmptiedFrameForgets() {
  StableText reading;
  reading.Scan("Line");
  reading.Scan("Line");
  for (int scan = 0; scan < kEmptyScansToForget; ++scan) reading.Scan("");
  reading.Scan("Line");
  Check(reading.Scan("Line").has_value(), "shown again after the frame emptied, it is said again");
}

void EmptyScanBreaksTheRun() {
  StableText reading;
  reading.Scan("Line");
  reading.Scan("");
  Check(!reading.Scan("Line"), "an empty scan between two readings breaks the run");
}

}  // namespace

int main() {
  SettledLineIsHandedOn();
  FlickerIsPassedOver();
  NextLineIsHandedOn();
  BlinkDoesNotRepeat();
  EmptiedFrameForgets();
  EmptyScanBreaksTheRun();
  if (failures > 0) return EXIT_FAILURE;
  std::printf("stable_text: all checks hold\n");
  return EXIT_SUCCESS;
}
