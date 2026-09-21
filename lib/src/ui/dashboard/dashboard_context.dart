// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/model_selection.dart';
import 'cubits/downloads_cubit.dart';
import 'cubits/settings_cubit.dart';
import '../shell/dashboard_providers.dart';

/// What the dashboard's widgets read off the cubits [DashboardProviders] provides
/// and that no one cubit owns.
extension DashboardContext on BuildContext {
  /// What the settings and the installed packages together decided, read
  /// without subscribing: whoever draws it listens to both for itself.
  ModelSelection get selection => ModelSelection(
    models: read<DownloadsCubit>().state.models,
    settings: read<SettingsCubit>().settings,
  );
}

/// A `buildWhen` that lets a [BlocBuilder] through only when [part] of the
/// state changes, compared as a value: a widget that draws a field or two of
/// a state names them here, and a download ticking or a phrase arriving
/// leaves it alone.
BlocBuilderCondition<S> whenChanged<S>(Object? Function(S state) part) =>
    (previous, current) => part(previous) != part(current);
