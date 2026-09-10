// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// A release published for the application, as the repository names it.
class AppRelease {
  const AppRelease({required this.version, required this.page});

  /// The tag without its leading `v`, so it compares as a version.
  final String version;

  /// Where a reader can see what changed.
  final Uri page;
}

/// How the check for a newer version is going.
enum UpdateStatus {
  /// Nothing has been asked yet.
  idle,
  checking,

  /// This build is the newest published one.
  current,

  /// A newer release exists.
  available,

  /// The check itself did not work — no network, a rate limit, a rewrite of
  /// the API. Not knowing is different from being up to date, and the
  /// interface says so rather than claiming the latter.
  failed,
}

/// What the interface shows beside the version.
class UpdateState {
  const UpdateState({
    this.status = UpdateStatus.idle,
    this.currentVersion = '',
    this.release,
    this.error,
  });

  final UpdateStatus status;

  /// The version this build reports for itself.
  final String currentVersion;

  /// The newer release, when there is one.
  final AppRelease? release;

  /// Why the check failed, as raised; written out by the interface.
  final Object? error;

  bool get checking => status == UpdateStatus.checking;
  bool get hasUpdate => status == UpdateStatus.available && release != null;

  UpdateState copyWith({
    UpdateStatus? status,
    String? currentVersion,
    AppRelease? release,
    bool clearRelease = false,
    Object? error,
    bool clearError = false,
  }) => UpdateState(
    status: status ?? this.status,
    currentVersion: currentVersion ?? this.currentVersion,
    release: clearRelease ? null : release ?? this.release,
    error: clearError ? null : error ?? this.error,
  );
}
