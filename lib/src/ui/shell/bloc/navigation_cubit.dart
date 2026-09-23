// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// In the order the navigation lists them; the compact bar picks by index.
/// The order the sections are listed in, which is the order the work is
/// done in: what the game says, a piece of it by hand, whose voices read it,
/// how the signal runs, what it runs on, and everything else.
enum DashboardSection { live, snapshot, characters, glossary, models, settings }

/// What the Эфир screen shows: the dubbing itself, or the scheme it runs
/// by. The scheme was a screen of its own under the preparations, which
/// meant leaving the dubbing to rewire it -- and it is the one thing there
/// that answers while the dubbing runs.
enum LiveView { dubbing, scheme }

/// What the Экран screen shows: its reading of the screen, or the scheme
/// that reading runs by -- the same two halves Эфир has, for the same
/// reason.
enum ScreenView { reading, scheme }

/// Which screen is open, and which half of Эфир and of Экран.
class NavigationState extends Equatable {
  const NavigationState({
    this.section = DashboardSection.live,
    this.liveView = LiveView.dubbing,
    this.screenView = ScreenView.reading,
  });

  final DashboardSection section;

  /// Which half of Эфир is up. Meaningless on any other screen.
  final LiveView liveView;

  /// Which half of Экран is up. Meaningless on any other screen.
  final ScreenView screenView;

  @override
  List<Object?> get props => [section, liveView, screenView];
}

/// Where the player stands in the dashboard.
///
/// A Cubit rather than a Bloc: every call is a setter, and a class of event
/// for each would say nothing a call does not.
// A setter and nothing more: a Cubit on purpose (CLAUDE.md).
// ignore: prefer_bloc
class NavigationCubit extends Cubit<NavigationState> {
  NavigationCubit() : super(const NavigationState());

  /// Opens [value], each screen with two halves showing the one it was
  /// left on.
  void selectSection(DashboardSection value) => emit(
    NavigationState(section: value, liveView: state.liveView, screenView: state.screenView),
  );

  /// Shows one half of Эфир: the dubbing, or the scheme it runs by. It
  /// comes back to Эфир first, so the checklist can send the player to the
  /// scheme from wherever they are standing.
  void showOnLive(LiveView view) => emit(
    NavigationState(section: DashboardSection.live, liveView: view, screenView: state.screenView),
  );

  /// Shows one half of Экран: the reading of the screen, or the scheme it
  /// runs by, coming back to Экран first as [showOnLive] comes to Эфир.
  void showOnScreen(ScreenView view) => emit(
    NavigationState(section: DashboardSection.snapshot, liveView: state.liveView, screenView: view),
  );
}
