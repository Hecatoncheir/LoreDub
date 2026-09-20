// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../common/setting_card.dart';
import '../dashboard/cubits/settings_cubit.dart';

/// Which of the two the window is drawn in, beside the language it speaks
/// and the size it is drawn at: the third thing a player sets for their own
/// eyes rather than for the dubbing.
class ThemeCard extends StatelessWidget {
  const ThemeCard({super.key, required this.settings});

  final AppSettings settings;

  static String _name(AppLocalizations l10n, InterfaceTheme theme) => switch (theme) {
    InterfaceTheme.system => l10n.themeSystem,
    InterfaceTheme.light => l10n.themeLight,
    InterfaceTheme.dark => l10n.themeDark,
  };

  static IconData _icon(InterfaceTheme theme) => switch (theme) {
    InterfaceTheme.system => Icons.brightness_auto_rounded,
    InterfaceTheme.light => Icons.light_mode_rounded,
    InterfaceTheme.dark => Icons.dark_mode_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingCard(
      title: l10n.settingsTheme,
      subtitle: l10n.themeNote,
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<InterfaceTheme>(
          key: const ValueKey('interfaceTheme'),
          segments: [
            for (final theme in InterfaceTheme.values)
              ButtonSegment(
                value: theme,
                icon: Icon(_icon(theme)),
                label: Text(_name(l10n, theme)),
              ),
          ],
          selected: {settings.interfaceTheme},
          onSelectionChanged: (selection) => context.read<SettingsCubit>().update(
            settings.copyWith(interfaceTheme: selection.first),
          ),
        ),
      ),
    );
  }
}
