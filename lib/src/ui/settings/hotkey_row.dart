// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../dashboard/cubits/settings_cubit.dart';
import 'hotkey_field.dart';
import '../hotkey_names.dart';

/// One action and the field that binds its combination.
///
/// A combination is refused when it would take a key from the game or one
/// another action already has; the others are read off the settings at the
/// moment of binding, not as they were when the row was drawn.
class HotkeyRow extends StatelessWidget {
  const HotkeyRow({
    super.key,
    required this.action,
    required this.settings,
    required this.enabled,
  });

  final HotkeyAction action;
  final AppSettings settings;
  final bool enabled;

  String? _problem(BuildContext context, AppLocalizations l10n, Hotkey hotkey) {
    final current = context.read<SettingsCubit>().settings;
    final problem = bindingProblem(hotkey, {
      for (final other in HotkeyAction.values)
        if (other != action) other: current.hotkeyFor(other),
    });
    return problem == null ? null : describeHotkeyProblem(l10n, problem);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 160,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              hotkeyActionName(l10n, action),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        Expanded(
          child: HotkeyField(
            key: ValueKey('${action.name}Hotkey'),
            value: settings.hotkeyFor(action),
            enabled: enabled,
            validate: (hotkey) => _problem(context, l10n, hotkey),
            onChanged: (hotkey) {
              final settings = context.read<SettingsCubit>();
              settings.update(settings.settings.withHotkey(action, hotkey));
            },
          ),
        ),
      ],
    );
  }
}
