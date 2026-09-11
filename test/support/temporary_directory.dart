// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

/// Windows errors that mean another process still has the directory or a
/// file in it open: sharing violation, access denied, and a directory whose
/// files are only pending deletion.
const _heldOpenErrors = {32, 5, 145};

/// Removes a test's temporary directory once nothing outside the test holds
/// it.
///
/// An on-access virus scanner opens a file the moment it is written or
/// renamed (archives such as `build.zip` always get a look), and while it
/// holds the file or the directory Windows refuses to remove the folder. The
/// delete then fails a test that has just passed and leaves an empty folder
/// in the temp directory. The hold lasts milliseconds, so the delete is
/// retried; a handle the code under test leaked would outlast every retry and
/// still fail the test.
Future<void> deleteOnceReleased(Directory directory) async {
  for (var attempt = 1; ; attempt++) {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
      return;
    } on FileSystemException catch (error) {
      if (attempt >= 20 || !_heldOpenErrors.contains(error.osError?.errorCode)) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}
