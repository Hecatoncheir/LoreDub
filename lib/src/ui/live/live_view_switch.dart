// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../dashboard/cubits/shell_cubit.dart';

/// Which half of Эфир is up: the dubbing itself, or the scheme it runs by.
///
/// The scheme used to be a screen under the preparations, which meant
/// leaving the dubbing to rewire it -- and it is the one arrangement that
/// answers while the dubbing runs.
class LiveViewSwitch extends StatelessWidget {
  const LiveViewSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocSelector<ShellCubit, ShellState, LiveView>(
      selector: (shell) => shell.liveView,
      builder: (context, view) => SegmentedButton<LiveView>(
        key: const ValueKey('liveView'),
        segments: [
          ButtonSegment(
            value: LiveView.dubbing,
            icon: const Icon(Icons.graphic_eq_rounded, size: 18),
            label: Text(l10n.navLive),
          ),
          ButtonSegment(
            value: LiveView.scheme,
            icon: const Icon(Icons.account_tree_rounded, size: 18),
            label: Text(l10n.navPipeline),
          ),
        ],
        selected: {view},
        showSelectedIcon: false,
        onSelectionChanged: (picked) => context.read<ShellCubit>().showOnLive(picked.first),
      ),
    );
  }
}
