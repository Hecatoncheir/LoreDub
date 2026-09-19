// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:lore_dub/src/data/services/directory_removal.dart';

/// Removes a test's temporary directory once nothing outside the test holds
/// it -- the same waiting the application does when a package is removed,
/// and for the same reason: an on-access virus scanner opens a file the
/// moment it is written, and while it holds one Windows refuses to remove
/// the folder. A handle the code under test leaked outlasts every attempt
/// and still fails the test.
Future<void> deleteOnceReleased(Directory directory) => deleteDirectory(directory);
