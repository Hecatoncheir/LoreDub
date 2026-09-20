// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../dashboard/cubits/shell_cubit.dart';
import 'live_title_word.dart';

/// The title of Эфир, which is also the switch between its two halves: the
/// dubbing, and the scheme it runs by. The one that is up is the title and
/// the other stands beside it, so the screen says what it is showing and
/// what else it could show in the same breath.
class LiveTitleSwitch extends StatelessWidget {
  const LiveTitleSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocSelector<ShellCubit, ShellState, LiveView>(
      selector: (shell) => shell.liveView,
      builder: (context, view) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          LiveTitleWord(
            key: const ValueKey('liveTitleDubbing'),
            label: l10n.liveViewDubbing,
            selected: view == LiveView.dubbing,
            onPressed: () => context.read<ShellCubit>().showOnLive(LiveView.dubbing),
          ),
          const SizedBox(width: 4),
          LiveTitleWord(
            key: const ValueKey('liveTitleScheme'),
            label: l10n.liveViewScheme,
            selected: view == LiveView.scheme,
            onPressed: () => context.read<ShellCubit>().showOnLive(LiveView.scheme),
          ),
        ],
      ),
    );
  }
}
