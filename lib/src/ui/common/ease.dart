// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/widgets.dart';

/// How long a change of face takes -- a card chosen, a pack lit by what is
/// dragged over it, a download's fill rising -- or nothing at all when the
/// player has turned animation off in Windows. Every implicit animation of
/// the interface takes its duration from here, so that one switch reaches
/// all of them.
Duration ease(BuildContext context, [int milliseconds = 200]) =>
    (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);
