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

enum DashboardSection { live, models, settings }

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
    if (state.updates.checking) return;
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
      updates = UpdateState(
        status: newer ? UpdateStatus.available : UpdateStatus.current,
        currentVersion: version,
        release: newer ? release : null,
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

  /// Stages a state a widget test wants to render without running anything.
  @visibleForTesting
  void seed(ShellState value) => emit(value);
}
