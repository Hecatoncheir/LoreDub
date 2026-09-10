// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Icons the bundled Material Icons font does not carry.
///
/// `audio_capture` only exists in Material Symbols, which Flutter's `Icons`
/// class does not cover, so it is shipped as the upstream SVG (Apache-2.0)
/// and tinted at draw time like any other icon.
abstract final class LoreDubIcons {
  static const _audioCaptureAsset = 'assets/icons/audio_capture.svg';

  /// The live-capture mark, drawn in [color] at [size] logical pixels.
  static Widget audioCapture({required Color color, double size = 24}) => SvgPicture.asset(
    _audioCaptureAsset,
    width: size,
    height: size,
    // The file carries the Material Symbols grey; the interface decides the
    // colour, exactly as it does for a font icon.
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}
