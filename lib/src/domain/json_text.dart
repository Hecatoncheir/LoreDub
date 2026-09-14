// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';

/// Reads JSON written by anything, not only by us.
///
/// A file that came from another machine — an exported cast, a scheme a
/// friend sent on — may have been opened in an editor since, and Windows
/// editors put a byte order mark in front of UTF-8. `jsonDecode` reads that
/// mark as a character and refuses the whole file, which would lose the
/// player their cards with nothing said about why.
Object? decodeJsonText(String text) => jsonDecode(text.startsWith('﻿') ? text.substring(1) : text);
