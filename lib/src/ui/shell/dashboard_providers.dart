// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../dashboard/cubits/characters_cubit.dart';
import '../dashboard/cubits/downloads_cubit.dart';
import '../dashboard/cubits/glossary_cubit.dart';
import '../dashboard/cubits/pipeline_cubit.dart';
import '../dashboard/cubits/pipeline_facts_bloc.dart';
import '../dashboard/cubits/pipeline_graph_bloc.dart';
import '../dashboard/cubits/settings_cubit.dart';
import '../dashboard/cubits/shell_cubit.dart';
import '../dashboard/cubits/sources_bloc.dart';
import '../dashboard/cubits/transcript_bloc.dart';

/// Every screen's state, made out of the repositories above it and put
/// under [child].
///
/// Each one is built in its own `create` from what it reads off the
/// context, and starts its own first read there: nothing holds them
/// together, because nothing has to. What more than one of them needs is
/// in a repository, the rule between the two that start sessions is
/// `SessionCoordinator`'s, and the first load a start waits for is the
/// shell's (`ShellCubit.start`). None of them is lazy: the pipeline has to
/// hear the engine and the canvas has to be read before anyone opens them.
///
/// The shell comes first, as every other one reports what went wrong to it.
/// The provider closes each of them when the application goes.
class DashboardProviders extends StatelessWidget {
  const DashboardProviders({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        lazy: false,
        create: (context) => ShellCubit(
          context.read(),
          context.read(),
          context.read(),
          context.read(),
          context.read(),
        )..start(),
      ),
      BlocProvider(
        lazy: false,
        create: (context) =>
            SettingsCubit(context.read(), context.read(), context.read<ShellCubit>())..load(),
      ),
      BlocProvider(
        lazy: false,
        create: (context) => DownloadsCubit(
          context.read(),
          context.read(),
          context.read(),
          context.read(),
          context.read<ShellCubit>(),
        ),
      ),
      BlocProvider(
        lazy: false,
        create: (context) =>
            SourcesBloc(context.read(), context.read<ShellCubit>())..add(const SourcesRefreshed()),
      ),
      BlocProvider(
        lazy: false,
        create: (context) => PipelineCubit(
          context.read(),
          context.read(),
          context.read(),
          context.read(),
          context.read(),
          context.read<ShellCubit>(),
          context.read(),
        )..listen(),
      ),
      BlocProvider(
        lazy: false,
        create: (context) =>
            TranscriptBloc(context.read(), context.read(), context.read<ShellCubit>()),
      ),
      BlocProvider(
        lazy: false,
        create: (context) => CharactersCubit(
          context.read(),
          context.read(),
          context.read(),
          context.read(),
          context.read<ShellCubit>(),
          context.read(),
          context.read(),
        )..load(),
      ),
      BlocProvider(
        lazy: false,
        create: (context) => GlossaryCubit(context.read(), context.read<ShellCubit>())..load(),
      ),
      BlocProvider(
        lazy: false,
        create: (context) => PipelineGraphBloc(
          context.read(),
          context.read(),
          context.read(),
          context.read(),
          context.read(),
          context.read<ShellCubit>(),
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
