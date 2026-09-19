// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/widgets.dart';

/// How long a change of face takes on the canvas — a card chosen, cut out
/// of the mix, or gone dark — or nothing at all when the player has turned
/// animation off in Windows.
Duration canvasEase(BuildContext context, [int milliseconds = 200]) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : Duration(milliseconds: milliseconds);
