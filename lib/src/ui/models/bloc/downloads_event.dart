// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

part of 'downloads_bloc.dart';

sealed class DownloadsEvent extends Equatable {
  const DownloadsEvent();

  @override
  List<Object?> get props => const [];
}

/// Fetches a model package, or resumes one that was paused.
final class ModelInstallAsked extends DownloadsEvent {
  const ModelInstallAsked(this.install);

  final ModelInstallState install;

  @override
  List<Object?> get props => [install.model.id];
}

/// Deletes a downloaded model to give its space back.
final class ModelRemoved extends DownloadsEvent {
  const ModelRemoved(this.install);

  final ModelInstallState install;

  @override
  List<Object?> get props => [install.model.id];
}

/// Fetches a GPU runtime, or resumes one that was paused.
final class RuntimeInstallAsked extends DownloadsEvent {
  const RuntimeInstallAsked(this.install);

  final RuntimeInstallState install;

  @override
  List<Object?> get props => [install.package.id];
}

final class RuntimeRemoved extends DownloadsEvent {
  const RuntimeRemoved(this.install);

  final RuntimeInstallState install;

  @override
  List<Object?> get props => [install.package.id];
}

/// Stops a download and keeps what arrived, so asking again resumes.
final class DownloadPaused extends DownloadsEvent {
  const DownloadPaused(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// Stops a download and throws away what arrived.
final class DownloadCancelled extends DownloadsEvent {
  const DownloadCancelled(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// Shows the player where the models are kept.
final class ModelDirectoryOpened extends DownloadsEvent {
  const ModelDirectoryOpened();
}

final class _InstalledChanged extends DownloadsEvent {
  const _InstalledChanged(this.parts);

  final InstalledParts parts;
}
