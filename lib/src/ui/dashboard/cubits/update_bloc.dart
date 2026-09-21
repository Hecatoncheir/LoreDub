// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/session_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/update_repository.dart';
import '../../../data/services/update_service.dart';
import '../../../domain/app_release.dart';
import '../../../domain/progress_ticker.dart';
import '../../../domain/session_coordinator.dart';
import 'failure_cubit.dart';

sealed class UpdateEvent extends Equatable {
  const UpdateEvent();

  @override
  List<Object?> get props => [];
}

/// Asks for the newest release. [announce] is the check made at startup,
/// whose news is raised as a toast as well as shown beside the version.
final class UpdatesChecked extends UpdateEvent {
  const UpdatesChecked({this.announce = false});

  final bool announce;

  @override
  List<Object?> get props => [announce];
}

/// The toast about the newer release, worded by the interface.
final class UpdateAnnounced extends UpdateEvent {
  const UpdateAnnounced({required this.title, required this.body});

  final String title;
  final String body;

  @override
  List<Object?> get props => [title, body];
}

/// Downloads the newer release's setup, or opens its page where this copy
/// cannot be replaced by it.
final class UpdateInstallAsked extends UpdateEvent {
  const UpdateInstallAsked();
}

final class ReleasePageOpened extends UpdateEvent {
  const ReleasePageOpened();
}

/// Closes the application into the downloaded setup.
final class UpdateRestartAsked extends UpdateEvent {
  const UpdateRestartAsked();
}

/// The version, and what is known about newer ones: check, download,
/// restart. A Bloc, as it is a process with progress rather than a setter.
class UpdateBloc extends Bloc<UpdateEvent, UpdateState> {
  UpdateBloc(this._updates, this._settings, this._session, this._sessions, this._failures)
    : super(const UpdateState()) {
    on<UpdatesChecked>(_onChecked);
    on<UpdateAnnounced>(_onAnnounced);
    on<ReleasePageOpened>((event, emit) => _openReleasePage());
    on<UpdateInstallAsked>(_onInstallAsked);
    on<UpdateRestartAsked>((event, emit) => _restart());
  }

  final UpdateRepository _updates;

  /// The proxy the check and the download go through.
  final SettingsRepository _settings;
  final SessionRepository _session;

  /// Who is holding the engine, asked before closing for an update.
  final SessionCoordinator _sessions;
  final FailureSink _failures;

  /// Failure is reported as [UpdateStatus.failed] rather than the usual error
  /// banner: not reaching GitHub says nothing about the dubbing, and a red
  /// bar across the screen would suggest otherwise.
  Future<void> _onChecked(UpdatesChecked event, Emitter<UpdateState> emit) async {
    // An update on its way, or waiting for its restart, is past checking.
    if (state.checking || state.installing || state.readyToRestart) return;
    emit(state.copyWith(status: UpdateStatus.checking, clearError: true));
    try {
      final found = await _askForTheLatest(state);
      emit(found.copyWith(announce: event.announce && found.hasUpdate));
    } catch (exception) {
      emit(state.copyWith(status: UpdateStatus.failed, error: exception));
    }
  }

  /// What the repository says the newest release is, against the version
  /// this build carries. A release that is not newer leaves the state
  /// saying so and nothing else.
  Future<UpdateState> _askForTheLatest(UpdateState updates) async {
    final version = updates.currentVersion.isNotEmpty
        ? updates.currentVersion
        : await _updates.currentVersion();
    // The proxy is the player's; read once whoever asks first.
    await _settings.load();
    final release = await _updates.latestRelease(proxyUrl: _settings.settings.modelProxyUrl);
    final newer = release != null && isNewerRelease(release.version, version);
    final installer = newer ? release.installer : null;
    final installable = installer != null && _updates.canInstall;
    return UpdateState(
      status: newer ? UpdateStatus.available : UpdateStatus.current,
      currentVersion: version,
      release: newer ? release : null,
      installable: installable,
      // A setup an earlier run finished downloading goes straight to the
      // restart rather than asking to be fetched a second time.
      installerPath: installable ? await _updates.downloadedInstaller(installer) : null,
    );
  }

  Future<void> _onAnnounced(UpdateAnnounced event, Emitter<UpdateState> emit) async {
    emit(state.copyWith(announce: false));
    try {
      await _updates.announce(title: event.title, body: event.body);
    } catch (_) {
      // A toast Windows would not show is no failure of the dubbing; the
      // version row says the same thing.
    }
  }

  Future<void> _openReleasePage() async {
    final release = state.release;
    if (release == null) return;
    try {
      await _updates.openPage(release.page);
    } catch (exception) {
      _failures.report(exception);
    }
  }

  /// A copy the setup cannot replace — a build run from its folder, or a
  /// release with no setup — is sent to the release page instead.
  Future<void> _onInstallAsked(UpdateInstallAsked event, Emitter<UpdateState> emit) async {
    final release = state.release;
    if (release == null || state.installing || state.readyToRestart) return;
    final installer = release.installer;
    if (!state.installable || installer == null) return _openReleasePage();
    _failures.report(null);
    emit(state.copyWith(installProgress: 0));
    final ticker = ProgressTicker();
    try {
      final setup = await _updates.downloadInstaller(
        installer,
        proxyUrl: _settings.settings.modelProxyUrl,
        onProgress: (value) {
          // Every chunk reports; only a change the reader can see redraws.
          if (emit.isDone || !ticker.shouldReport(value)) return;
          emit(state.copyWith(installProgress: value));
        },
      );
      emit(state.copyWith(clearInstallProgress: true, installerPath: setup));
    } catch (exception) {
      emit(state.copyWith(clearInstallProgress: true));
      _failures.report(exception);
    }
  }

  /// Stops what is running, then closes the application so the downloaded
  /// setup can replace it and open the new version.
  Future<void> _restart() async {
    final setup = state.installerPath;
    if (setup == null) return;
    try {
      // Closing must not leave the game turned down, or the worker of
      // either screen still holding the files the setup replaces.
      if (_sessions.anyRuns) await _session.stop();
      await _updates.restartInto(setup);
    } catch (exception) {
      _failures.report(exception);
    }
  }
}
