// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What every bloc and cubit did, in order.
///
/// A dubbing session is thirteen kinds of engine event landing among the
/// player's own presses, and a complaint usually arrives as one sentence:
/// "it stopped". Reading that against a list of what changed and in what
/// order is a different job from reading it against nothing.
///
/// The lines are kept in memory rather than written to a file: they are for
/// the run that is happening, and a log on disk is a promise to rotate it,
/// to keep the player's process names out of it, and to ship a way of
/// sending it. [lines] is what a report would be built from when there is
/// one to build.
class StateJournal extends BlocObserver {
  StateJournal({this.kept = 400, this.echo = kDebugMode});

  /// How many lines are worth keeping. A drag on the canvas is a state per
  /// frame, so a journal without a ceiling is the whole session's frames.
  final int kept;

  /// Whether each line also goes to the console, which is what a developer
  /// watching a run wants and a player has no use for.
  final bool echo;

  final _lines = <String>[];

  /// The journal as it stands, oldest first.
  List<String> get lines => List.unmodifiable(_lines);

  void clear() => _lines.clear();

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    _write('${bloc.runtimeType} <- ${_shortly(event)}');
  }

  /// Only the fact of a change and which state it is now. The states here
  /// hold transcripts and whole schemes, so writing one out would bury the
  /// line it belongs to -- and a `toString` of a list of sixty lines is not
  /// a thing to build sixty times a second.
  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    _write('${bloc.runtimeType} -> ${change.nextState.runtimeType}');
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    _write('${bloc.runtimeType} !! $error');
  }

  void _write(String line) {
    if (_lines.length >= kept) _lines.removeAt(0);
    _lines.add(line);
    if (echo) debugPrint(line);
  }

  /// An event as one line. A `toString` that was never meant to be read --
  /// `Instance of 'PipelineNodeMoved'` -- says only the type, which is what
  /// the type says anyway, so it is dropped.
  static String _shortly(Object? event) {
    final written = '$event';
    return written.startsWith('Instance of') ? '${event.runtimeType}' : written;
  }
}
