// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../dashboard/cubits/navigation_cubit.dart';
import '../theme.dart';

/// How a snippet is taken -- the key held -- or, with no key set, the way to
/// the settings where one is.
class SnapshotHotkeyLine extends StatelessWidget {
  const SnapshotHotkeyLine({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hotkey = settings.snapshotHotkey;
    if (hotkey != null) {
      return Text(l10n.snapshotHowTo(hotkey.display), style: Theme.of(context).textTheme.bodyLarge);
    }
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          l10n.snapshotNoHotkey,
          style: TextStyle(color: context.colors.warning, fontWeight: FontWeight.w600),
        ),
        TextButton(
          onPressed: () => context.read<NavigationCubit>().selectSection(DashboardSection.settings),
          child: Text(l10n.snapshotOpenSettings),
        ),
      ],
    );
  }
}
