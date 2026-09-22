// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

/// Starts a program with its arguments, as `Process.start` does. The seam the
/// worker, whisper and the update's setup are started through: the tests
/// start none of them.
typedef ProcessLauncher = Future<Process> Function(String executable, List<String> arguments);
