// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../dashboard/cubits/navigation_cubit.dart';
import '../theme.dart';
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
    return BlocSelector<NavigationCubit, NavigationState, LiveView>(
      selector: (shell) => shell.liveView,
      builder: (context, view) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          LiveTitleWord(
            key: const ValueKey('liveTitleDubbing'),
            label: l10n.liveViewDubbing,
            icon: Icons.graphic_eq_rounded,
            selected: view == LiveView.dubbing,
            onPressed: () => context.read<NavigationCubit>().showOnLive(LiveView.dubbing),
          ),
          // The two are one title with a choice in it, so they are
          // parted the way the marking above them parts its halves.
          Text(
            '/',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: context.colors.outline,
            ),
          ),
          LiveTitleWord(
            key: const ValueKey('liveTitleScheme'),
            label: l10n.liveViewScheme,
            icon: Icons.account_tree_rounded,
            selected: view == LiveView.scheme,
            onPressed: () => context.read<NavigationCubit>().showOnLive(LiveView.scheme),
          ),
        ],
      ),
    );
  }
}
