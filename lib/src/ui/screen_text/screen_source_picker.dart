// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../settings/bloc/settings_bloc.dart';

/// Whether the game's window is read or the whole screen.
///
/// A window is read only while it is in front, so nothing put over the game
/// can pass for its subtitles; the screen is read whatever is on it, which
/// is the only way into a game that keeps no ordinary window.
class ScreenSourcePicker extends StatelessWidget {
  const ScreenSourcePicker({super.key, required this.settings, required this.locked});

  final AppSettings settings;

  /// A session is running, and reads what it started on.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ScreenSource>(
        segments: [
          ButtonSegment(
            value: ScreenSource.gameWindow,
            icon: const Icon(Icons.crop_din_rounded),
            label: Text(l10n.screenSourceWindow),
          ),
          ButtonSegment(
            value: ScreenSource.wholeScreen,
            icon: const Icon(Icons.desktop_windows_outlined),
            label: Text(l10n.screenSourceScreen),
          ),
        ],
        selected: {settings.screenSource},
        onSelectionChanged: locked
            ? null
            : (selection) => context.read<SettingsBloc>().add(
                SettingsChanged(
                  settings.copyWith(screenSource: selection.first),
                ),
              ),
      ),
    );
  }
}
