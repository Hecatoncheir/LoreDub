// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// The frame drawn on the screen, turned into the share of a window it
// covers, and a frame written by hand put back in order.

#include "screen_region.h"

#include <cmath>
#include <cstdio>
#include <cstdlib>

namespace {

int failures = 0;

void Check(bool holds, const char* what) {
  if (holds) return;
  std::printf("FAILED: %s\n", what);
  ++failures;
}

bool Near(double a, double b) { return std::fabs(a - b) < 1e-9; }

bool Is(const OcrRegion& region, double left, double top, double right, double bottom) {
  return Near(region.left, left) && Near(region.top, top) && Near(region.right, right) &&
         Near(region.bottom, bottom);
}

// A window at (100, 200), 1000 by 500.
constexpr ScreenArea kWindow{100, 200, 1100, 700};

void AreaInsideTheWindow() {
  OcrRegion region;
  Check(RegionWithin(kWindow, ScreenArea{100, 450, 1100, 700}, &region),
        "a frame inside the window is taken");
  Check(Is(region, 0.0, 0.5, 1.0, 1.0), "as the share of the window it covers");
  Check(RegionWithin(kWindow, ScreenArea{350, 325, 600, 450}, &region), "a frame in the middle");
  Check(Is(region, 0.25, 0.25, 0.5, 0.5), "measured from the window's own corner");
}

void AreaPastTheEdge() {
  OcrRegion region;
  Check(RegionWithin(kWindow, ScreenArea{0, 600, 2000, 900}, &region),
        "a frame drawn past the edge is taken");
  Check(Is(region, 0.0, 0.8, 1.0, 1.0), "and stops at the edge");
}

void AreaBesideTheWindow() {
  OcrRegion region{0.1, 0.1, 0.2, 0.2};
  Check(!RegionWithin(kWindow, ScreenArea{1200, 200, 1500, 700}, &region),
        "a frame beside the window is nothing");
  Check(Is(region, 0.1, 0.1, 0.2, 0.2), "and leaves the frame it was given alone");
  Check(!RegionWithin(kWindow, ScreenArea{500, 400, 510, 600}, &region),
        "a sliver narrower than the smallest share is nothing");
  Check(!RegionWithin(ScreenArea{0, 0, 0, 0}, ScreenArea{0, 0, 10, 10}, &region),
        "a window of no size holds no frame");
}

void RegionPutInOrder() {
  Check(Is(SanitizeRegion(OcrRegion{0.9, 0.8, 0.1, 0.2}), 0.1, 0.2, 0.9, 0.8),
        "edges given the wrong way round are swapped");
  Check(Is(SanitizeRegion(OcrRegion{-0.5, 0.5, 1.5, 2.0}), 0.0, 0.5, 1.0, 1.0),
        "edges outside the window are brought inside it");
  const OcrRegion fallback;
  Check(Is(SanitizeRegion(OcrRegion{0.5, 0.5, 0.51, 0.9}), fallback.left, fallback.top,
           fallback.right, fallback.bottom),
        "a sliver falls back to the default band");
}

}  // namespace

int main() {
  AreaInsideTheWindow();
  AreaPastTheEdge();
  AreaBesideTheWindow();
  RegionPutInOrder();
  if (failures > 0) return EXIT_FAILURE;
  std::printf("screen_region: all checks hold\n");
  return EXIT_SUCCESS;
}
