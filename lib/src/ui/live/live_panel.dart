// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../common/ease.dart';
import '../dashboard/cubits/navigation_cubit.dart';
import '../graph/pipeline_panel.dart';
import 'live_dubbing.dart';

/// The Эфир screen: where the sound comes from and in which language it is
/// dubbed, the start button, and below them the transcript and the voices
/// of the scene -- or the scheme the dubbing runs by, which is the other
/// half of the same screen rather than a place to walk to.
class LivePanel extends StatelessWidget {
  const LivePanel({super.key});

  @override
  Widget build(BuildContext context) => BlocSelector<NavigationCubit, NavigationState, LiveView>(
    selector: (shell) => shell.liveView,
    builder: (context, view) => AnimatedSwitcher(
      duration: ease(context, 180),
      child: switch (view) {
        LiveView.dubbing => const LiveDubbing(key: ValueKey('dubbing')),
        LiveView.scheme => PipelinePanel(key: const ValueKey('scheme')),
      },
    ),
  );
}
