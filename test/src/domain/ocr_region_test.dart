// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/ocr_region.dart';

void main() {
  test('starts on the lower band builds before the frame scanned', () {
    expect(OcrRegion.standard, const OcrRegion(left: 0, top: 0.55, right: 1, bottom: 1));
  });

  test('spans two corners given in either order', () {
    expect(
      OcrRegion.fromCorners(0.8, 0.9, 0.2, 0.6),
      const OcrRegion(left: 0.2, top: 0.6, right: 0.8, bottom: 0.9),
    );
  });

  test('keeps a frame drawn past the screen on it', () {
    expect(
      OcrRegion.fromCorners(-0.3, 0.5, 1.4, 1.2),
      const OcrRegion(left: 0, top: 0.5, right: 1, bottom: 1),
    );
  });

  test('grows a click into the smallest frame, still on the screen', () {
    final region = OcrRegion.fromCorners(0.99, 0.99, 0.99, 0.99);

    expect(region.right, 1);
    expect(region.bottom, 1);
    expect(region.width, closeTo(OcrRegion.minimumWidth, 1e-9));
    expect(region.height, closeTo(OcrRegion.minimumHeight, 1e-9));
  });

  test('moves as a whole and stops at the edge without shrinking', () {
    const region = OcrRegion(left: 0.2, top: 0.6, right: 0.6, bottom: 0.9);

    final moved = region.translated(0.7, -0.1);

    expect(moved.right, 1);
    expect(moved.width, closeTo(region.width, 1e-9));
    expect(moved.top, closeTo(0.5, 1e-9));
    expect(moved.height, closeTo(region.height, 1e-9));
  });

  test('moves only the edges it is given', () {
    const region = OcrRegion(left: 0.2, top: 0.6, right: 0.6, bottom: 0.9);

    expect(
      region.withEdges(left: 0.1, bottom: 0.95),
      const OcrRegion(left: 0.1, top: 0.6, right: 0.6, bottom: 0.95),
    );
  });

  test('stops an edge short of the minimum against the opposite one', () {
    const region = OcrRegion(left: 0.2, top: 0.6, right: 0.6, bottom: 0.9);

    final squeezed = region.withEdges(left: 0.9, top: 0.95);

    expect(squeezed.right, 0.6);
    expect(squeezed.width, closeTo(OcrRegion.minimumWidth, 1e-9));
    expect(squeezed.bottom, 0.9);
    expect(squeezed.height, closeTo(OcrRegion.minimumHeight, 1e-9));
  });
}
