// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../common/title_word.dart';
import '../shell/bloc/navigation_cubit.dart';
import '../theme.dart';
import 'screen_layout.dart';

/// The title of Экран, which is also the switch between its two halves:
/// the reading of the screen, and the scheme it runs by -- the same switch
/// Эфир's title is, for the same two halves of another session.
///
/// Its first word is a long one, and a narrow window leaves the header
/// little room beside the session's chip: there the half that is not up
/// stands as its mark alone, and what still does not fit is drawn smaller
/// rather than run off the edge.
class ScreenTitleSwitch extends StatelessWidget {
  const ScreenTitleSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocSelector<NavigationCubit, NavigationState, ScreenView>(
      selector: (shell) => shell.screenView,
      builder: (context, view) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < ScreenLayout.titleSwitchWidth;
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                TitleWord(
                  key: const ValueKey('screenTitleReading'),
                  label: l10n.screenViewReading,
                  // The mark the page carries in the navigation.
                  icon: Icons.highlight_alt_rounded,
                  selected: view == ScreenView.reading,
                  compact: compact,
                  onPressed: () => context.read<NavigationCubit>().showOnScreen(ScreenView.reading),
                ),
                Text(
                  '/',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: context.colors.outline,
                  ),
                ),
                TitleWord(
                  key: const ValueKey('screenTitleScheme'),
                  label: l10n.screenViewScheme,
                  icon: Icons.account_tree_rounded,
                  selected: view == ScreenView.scheme,
                  compact: compact,
                  onPressed: () => context.read<NavigationCubit>().showOnScreen(ScreenView.scheme),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
