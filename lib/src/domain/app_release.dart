// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// The Windows setup a release ships: what an update downloads and runs.
class ReleaseInstaller {
  const ReleaseInstaller({
    required this.name,
    required this.url,
    required this.size,
    this.sha256,
  });

  final String name;
  final Uri url;
  final int size;

  /// The digest GitHub publishes for the file, when it does.
  final String? sha256;
}

/// A release published for the application, as the repository names it.
class AppRelease {
  const AppRelease({required this.version, required this.page, this.installer});

  /// The tag without its leading `v`, so it compares as a version.
  final String version;

  /// Where a reader can see what changed.
  final Uri page;

  /// The setup among the release's files, if the release has one.
  final ReleaseInstaller? installer;
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
    this.installable = false,
    this.installProgress,
    this.installerPath,
  });

  final UpdateStatus status;

  /// The version this build reports for itself.
  final String currentVersion;

  /// The newer release, when there is one.
  final AppRelease? release;

  /// Why the check failed, as raised; written out by the interface.
  final Object? error;

  /// Whether this copy can be updated in place: the setup put it there and
  /// the release ships a setup. A build run from its folder is only pointed
  /// at the release page.
  final bool installable;

  /// How far the newer setup has downloaded, while it does.
  final double? installProgress;

  /// The downloaded setup, waiting for the restart that runs it.
  final String? installerPath;

  bool get checking => status == UpdateStatus.checking;
  bool get hasUpdate => status == UpdateStatus.available && release != null;
  bool get installing => installProgress != null;
  bool get readyToRestart => installerPath != null;

  UpdateState copyWith({
    UpdateStatus? status,
    String? currentVersion,
    AppRelease? release,
    bool clearRelease = false,
    Object? error,
    bool clearError = false,
    bool? installable,
    double? installProgress,
    bool clearInstallProgress = false,
    String? installerPath,
  }) => UpdateState(
    status: status ?? this.status,
    currentVersion: currentVersion ?? this.currentVersion,
    release: clearRelease ? null : release ?? this.release,
    error: clearError ? null : error ?? this.error,
    installable: installable ?? this.installable,
    installProgress: clearInstallProgress ? null : installProgress ?? this.installProgress,
    installerPath: installerPath ?? this.installerPath,
  );
}
