// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/capture_sources.dart';
import '../dashboard/cubits/sources_bloc.dart';
import 'process_picker.dart';

/// The one game every screen listens to, as a field.
///
/// Four screens draw it -- Live, the Screen page, the characters'
/// recording and the node panel -- and each used to wire the same list,
/// the same choice and the same refresh to the same cubit by hand. What
/// differs between them is only when the choice is closed.
class GamePicker extends StatelessWidget {
  const GamePicker({super.key, this.enabled = true});

  /// A running session holds the game it started with.
  final bool enabled;

  @override
  Widget build(BuildContext context) => BlocBuilder<SourcesBloc, CaptureSources>(
    // The monitors are no business of this field.
    buildWhen: (was, now) => was.processes != now.processes || was.selected != now.selected,
    builder: (context, sources) => ProcessPicker(
      processes: sources.processes,
      selected: sources.selected,
      enabled: enabled,
      onSelected: (process) => context.read<SourcesBloc>().add(SourcePicked(process)),
      onRefresh: () => context.read<SourcesBloc>().add(const SourcesRefreshed()),
    ),
  );
}
