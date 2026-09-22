// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../dashboard/cubits/cast_bloc.dart';
import '../dashboard/cubits/downloads_bloc.dart';
import '../dashboard/cubits/glossary_bloc.dart';
import '../dashboard/cubits/session_bloc.dart';
import '../dashboard/cubits/pipeline_facts_bloc.dart';
import '../dashboard/cubits/pipeline_graph_bloc.dart';
import '../dashboard/cubits/settings_bloc.dart';
import '../dashboard/cubits/failure_cubit.dart';
import '../dashboard/cubits/navigation_cubit.dart';
import '../dashboard/cubits/startup_cubit.dart';
import '../dashboard/cubits/update_bloc.dart';
import '../dashboard/cubits/sources_bloc.dart';
import '../dashboard/cubits/transcript_bloc.dart';
import '../dashboard/cubits/voice_capture_bloc.dart';

/// Every screen's state, made out of the repositories above it and put
/// under [child].
///
/// Each one is built in its own `create` from what it reads off the
/// context, and starts its own first read there: nothing holds them
/// together, because nothing has to. What more than one of them needs is
/// in a repository, the rule between the two that start sessions is
/// `SessionCoordinator`'s, and the first load a start waits for is the
/// `StartupCubit`'s. None of them is lazy: the pipeline has to
/// hear the engine and the canvas has to be read before anyone opens them.
///
/// The banner comes first, as every other one reports what went wrong to it.
/// The provider closes each of them when the application goes.
class DashboardProviders extends StatelessWidget {
  const DashboardProviders({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(lazy: false, create: (_) => FailureCubit()),
      BlocProvider(create: (_) => NavigationCubit()),
      BlocProvider(
        lazy: false,
        create: (context) {
          final startup = StartupCubit(
            context.read(),
            context.read(),
            context.read(),
            context.read<FailureCubit>(),
          );
          // Its own failures go to the banner; nothing here waits for it.
          unawaited(startup.start());
          return startup;
        },
      ),
      // Asked once the first load is back (`UpdateAnnouncer`).
      BlocProvider(
        lazy: false,
        create: (context) => UpdateBloc(
          context.read(),
          context.read(),
          context.read(),
          context.read(),
          context.read<FailureCubit>(),
        ),
      ),
      BlocProvider(
        lazy: false,
        create: (context) => SettingsBloc(
          context.read(),
          context.read(),
          context.read<FailureCubit>(),
          context.read(),
          context.read(),
        )..add(const SettingsOpened()),
      ),
      BlocProvider(
        lazy: false,
        create: (context) => DownloadsBloc(
          context.read(),
          context.read(),
          context.read(),
          context.read(),
          context.read<FailureCubit>(),
        ),
      ),
      BlocProvider(
        lazy: false,
        create: (context) =>
            SourcesBloc(context.read(), context.read<FailureCubit>())
              ..add(const SourcesRefreshed()),
      ),
      BlocProvider(
        lazy: false,
        create: (context) => SessionBloc(
          context.read(),
          context.read(),
          context.read(),
          context.read(),
          context.read(),
          context.read<FailureCubit>(),
          context.read(),
          context.read(),
        )..listen(),
      ),
      BlocProvider(
        lazy: false,
        create: (context) =>
            TranscriptBloc(context.read(), context.read(), context.read<FailureCubit>()),
      ),
      BlocProvider(
        lazy: false,
        create: (context) =>
            CastBloc(context.read(), context.read<FailureCubit>())..add(const CastOpened()),
      ),
      BlocProvider(
        lazy: false,
        create: (context) => VoiceCaptureBloc(
          context.read(),
          context.read(),
          context.read(),
          context.read(),
          context.read<FailureCubit>(),
          context.read(),
          context.read(),
        )..add(const VoiceCaptureOpened()),
      ),
      BlocProvider(
        lazy: false,
        create: (context) =>
            GlossaryBloc(context.read(), context.read<FailureCubit>())..add(const GlossaryOpened()),
      ),
      BlocProvider(
        lazy: false,
        create: (context) => PipelineGraphBloc(
          context.read(),
          context.read(),
          context.read(),
          context.read(),
          context.read(),
          context.read<FailureCubit>(),
        )..add(const PipelineGraphOpened()),
      ),
      BlocProvider(
        lazy: false,
        create: (context) => PipelineFactsBloc(
          context.read(),
          context.read(),
          context.read(),
          context.read(),
          context.read(),
        ),
      ),
    ],
    child: child,
  );
}
