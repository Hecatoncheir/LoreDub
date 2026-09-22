// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// The frame the screen is read through, as the player draws it and as it is
// kept: pure arithmetic, tried on its own (native/tests/screen_region_test.cpp).

#ifndef LORE_DUB_SCREEN_REGION_H_
#define LORE_DUB_SCREEN_REGION_H_

#include <algorithm>

// The part of the game window's client area -- or of the whole screen, when
// that is what is read -- to take the text out of, each edge a fraction of
// its width or height from the top-left corner.
struct OcrRegion {
  double left = 0.0;
  double top = 0.55;
  double right = 1.0;
  double bottom = 1.0;
};

// A rectangle of the screen in physical pixels, right and bottom exclusive.
struct ScreenArea {
  int left = 0;
  int top = 0;
  int right = 0;
  int bottom = 0;
};

// The narrowest a frame may be, as a share of either side: anything less
// holds no line of text and would leave the capture reading nothing.
inline constexpr double kSmallestRegionShare = 0.02;

// [region] put in order and inside the window, or the default frame when
// what is left of it is too small to read. The interface already keeps the
// frame valid; this guards the ABI against a config written by hand.
inline OcrRegion SanitizeRegion(OcrRegion region) {
  const double left = std::clamp(std::min(region.left, region.right), 0.0, 1.0);
  const double right = std::clamp(std::max(region.left, region.right), 0.0, 1.0);
  const double top = std::clamp(std::min(region.top, region.bottom), 0.0, 1.0);
  const double bottom = std::clamp(std::max(region.top, region.bottom), 0.0, 1.0);
  if (right - left < kSmallestRegionShare || bottom - top < kSmallestRegionShare) {
    return OcrRegion{};
  }
  return OcrRegion{left, top, right, bottom};
}

// The part of [bounds] that [area] covers, as fractions, or false when the
// rectangle fell outside it or came to nothing. A player who drew past the
// edge gets the edge, and one who drew beside it entirely gets nothing.
inline bool RegionWithin(ScreenArea bounds, ScreenArea area, OcrRegion* region) {
  const double width = bounds.right - bounds.left;
  const double height = bounds.bottom - bounds.top;
  if (width <= 0 || height <= 0) return false;
  const double left = std::clamp((area.left - bounds.left) / width, 0.0, 1.0);
  const double right = std::clamp((area.right - bounds.left) / width, 0.0, 1.0);
  const double top = std::clamp((area.top - bounds.top) / height, 0.0, 1.0);
  const double bottom = std::clamp((area.bottom - bounds.top) / height, 0.0, 1.0);
  if (right - left < kSmallestRegionShare || bottom - top < kSmallestRegionShare) return false;
  *region = OcrRegion{left, top, right, bottom};
  return true;
}

#endif  // LORE_DUB_SCREEN_REGION_H_
