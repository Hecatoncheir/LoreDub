// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../data/repositories/update_repository.dart';
import '../../../data/services/update_service.dart';
import '../../../domain/app_release.dart';
import '../../../domain/app_settings.dart';
import '../../../domain/progress_ticker.dart';

/// In the order the navigation lists them; the compact bar picks by index.
enum DashboardSection { live, snapshot, models, settings }

/// Where the parts of the dashboard put what went wrong.
///
/// Any stage can fail, but the interface shows one banner, so the shell owns
/// the message and everyone else hands it over instead of keeping a copy.
abstract class FailureSink {
  void report(Object? error);
}

/// The frame around the work: which section is open, whether the first load
/// is still running, the failure banner, and the update check.
class ShellState {
  const ShellState({
    this.section = DashboardSection.live,
    this.initializing = true,
    this.error,
    this.updates = const UpdateState(),
  });

  final DashboardSection section;
  final bool initializing;

  /// What went wrong, as raised. The interface writes it out.
  final Object? error;

  /// The version this build reports, and whether a newer one is published.
  final UpdateState updates;

  ShellState copyWith({
    DashboardSection? section,
    bool? initializing,
    Object? error,
    bool clearError = false,
    UpdateState? updates,
  }) => ShellState(
    section: section ?? this.section,
    initializing: initializing ?? this.initializing,
    error: clearError ? null : error ?? this.error,
    updates: updates ?? this.updates,
  );
}

class ShellCubit extends Cubit<ShellState> implements FailureSink {
  ShellCubit(this._updateRepository) : super(const ShellState());

  final UpdateRepository _updateRepository;

  /// Read when a toast has to be worded outside any widget tree, and when
  /// the check goes through a proxy. Both live in the settings, which are
  /// built after the shell, so they are handed over rather than injected.
  String Function()? interfaceLanguage;

  /// The proxy the update check should go through, if the user set one.
  String Function()? proxyUrl;

  /// Run before the application closes for an update, so dubbing stops and
  /// the game's volume comes back rather than staying turned down.
  Future<void> Function()? beforeRestart;

  @override
  void report(Object? error) {
    if (isClosed) return;
    emit(state.copyWith(error: error, clearError: error == null));
  }

  void selectSection(DashboardSection value) => emit(state.copyWith(section: value));

  void finishInitializing() => emit(state.copyWith(initializing: false));

  /// Asks the repository for the newest release.
  ///
  /// Failure is reported as [UpdateStatus.failed] rather than the usual error
  /// banner: not reaching GitHub says nothing about the dubbing, and a red
  /// bar across the screen would suggest otherwise.
  Future<void> checkForUpdates({bool announce = false}) async {
    // An update on its way, or waiting for its restart, is past checking.
    final current = state.updates;
    if (current.checking || current.installing || current.readyToRestart) return;
    emit(
      state.copyWith(
        updates: state.updates.copyWith(status: UpdateStatus.checking, clearError: true),
      ),
    );
    var updates = state.updates;
    try {
      final version = updates.currentVersion.isNotEmpty
          ? updates.currentVersion
          : await _updateRepository.currentVersion();
      final release = await _updateRepository.latestRelease(proxyUrl: proxyUrl?.call() ?? '');
      final newer = release != null && isNewerRelease(release.version, version);
      final installer = newer ? release.installer : null;
      final installable = installer != null && _updateRepository.canInstall;
      updates = UpdateState(
        status: newer ? UpdateStatus.available : UpdateStatus.current,
        currentVersion: version,
        release: newer ? release : null,
        installable: installable,
        // A setup an earlier run finished downloading goes straight to the
        // restart rather than asking to be fetched a second time.
        installerPath: installable ? await _updateRepository.downloadedInstaller(installer) : null,
      );
      if (newer && announce) {
        // The toast is raised outside any widget, so the wording is loaded
        // for the interface language rather than read from a context.
        final l10n = await AppLocalizations.delegate.load(
          Locale(interfaceLanguage?.call() ?? const AppSettings().interfaceLanguage),
        );
        await _updateRepository.announce(
          title: l10n.updateAvailableTitle,
          body: l10n.updateAvailableBody(release.version),
        );
      }
    } catch (exception) {
      updates = updates.copyWith(status: UpdateStatus.failed, error: exception);
    }
    if (isClosed) return;
    emit(state.copyWith(updates: updates));
  }

  Future<void> openReleasePage() async {
    final release = state.updates.release;
    if (release == null) return;
    try {
      await _updateRepository.openPage(release.page);
    } catch (exception) {
      report(exception);
    }
  }

  /// Downloads the newer release's setup, reporting how far it got. A copy
  /// the setup cannot replace — a build run from its folder, or a release
  /// with no setup — is sent to the release page instead.
  Future<void> installUpdate() async {
    final updates = state.updates;
    final release = updates.release;
    if (release == null || updates.installing || updates.readyToRestart) return;
    final installer = release.installer;
    if (!updates.installable || installer == null) return openReleasePage();
    report(null);
    emit(state.copyWith(updates: updates.copyWith(installProgress: 0)));
    final ticker = ProgressTicker();
    try {
      final setup = await _updateRepository.downloadInstaller(
        installer,
        proxyUrl: proxyUrl?.call() ?? '',
        onProgress: (value) {
          // Every chunk reports; only a change the reader can see redraws.
          if (isClosed || !ticker.shouldReport(value)) return;
          emit(state.copyWith(updates: state.updates.copyWith(installProgress: value)));
        },
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          updates: state.updates.copyWith(clearInstallProgress: true, installerPath: setup),
        ),
      );
    } catch (exception) {
      if (isClosed) return;
      emit(state.copyWith(updates: state.updates.copyWith(clearInstallProgress: true)));
      report(exception);
    }
  }

  /// Stops what is running, then closes the application so the downloaded
  /// setup can replace it and open the new version.
  Future<void> restartToUpdate() async {
    final setup = state.updates.installerPath;
    if (setup == null) return;
    try {
      await beforeRestart?.call();
      await _updateRepository.restartInto(setup);
    } catch (exception) {
      report(exception);
    }
  }

  /// Stages a state a widget test wants to render without running anything.
  @visibleForTesting
  void seed(ShellState value) => emit(value);
}
