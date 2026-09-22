// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/install_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/system_repository.dart';
import '../../../domain/failure.dart';
import 'failure_cubit.dart';

/// Whether the first load is still running: true until it has come back,
/// whatever it came back with. Every start button waits for it.
// A setter and nothing more: a Cubit on purpose (CLAUDE.md).
// ignore: prefer_bloc
class StartupCubit extends Cubit<bool> {
  StartupCubit(this._settings, this._installed, this._system, this._failures) : super(true);

  final SettingsRepository _settings;

  /// What is on disk and what the machine can run it on, which is what a
  /// session cannot be started without knowing.
  final InstallRepository _installed;

  /// The machine's adapters, which the first load asks for.
  final SystemRepository _system;
  final FailureSink _failures;

  /// The first load: what a start is refused without until it is known.
  ///
  /// The settings and what is installed, with the machine's adapters, and
  /// nothing else. Every screen reads the rest for itself as it is created
  /// -- the cast, the glossary, the processes -- and says itself what went
  /// wrong with it; none of that stands between the player and a start.
  /// The update check is `UpdateBloc`'s, and does not wait on this either.
  Future<void> start() async {
    try {
      final graphics = _system.probeGraphics();
      await Future.wait([_settings.load(), _installed.load()]);
      await _installed.refreshAvailability(probe: await graphics);
    } catch (exception) {
      _failures.report(LoreDubFailure(FailureCode.initializationFailed, detail: '$exception'));
    } finally {
      if (!isClosed) emit(false);
    }
  }
}
