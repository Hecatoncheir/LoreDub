// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../common/ease.dart';
import '../shell/bloc/navigation_cubit.dart';
import 'screen_scheme_panel.dart';
import 'snapshot_panel.dart';

/// The Экран screen: the reading of the screen -- the game, the language,
/// the frame and what the two ways of reading have read -- or the scheme
/// that reading runs by, which is the other half of the same screen, as
/// Эфир's scheme is of Эфир.
class ScreenPanel extends StatelessWidget {
  const ScreenPanel({super.key});

  @override
  Widget build(BuildContext context) => BlocSelector<NavigationCubit, NavigationState, ScreenView>(
    selector: (shell) => shell.screenView,
    builder: (context, view) => AnimatedSwitcher(
      duration: ease(context, 180),
      child: switch (view) {
        ScreenView.reading => const SnapshotPanel(key: ValueKey('reading')),
        ScreenView.scheme => const ScreenSchemePanel(key: ValueKey('screenScheme')),
      },
    ),
  );
}
