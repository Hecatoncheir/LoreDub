// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../dashboard/cubits/settings_cubit.dart';

/// Looks for an interpreter that has what the worker needs, and says so
/// while it looks.
class PythonSearchButton extends StatelessWidget {
  const PythonSearchButton({super.key, required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) => BlocSelector<SettingsCubit, SettingsState, bool>(
    selector: (state) => state.searchingPython,
    builder: (context, searching) {
      final l10n = AppLocalizations.of(context);
      return TextButton.icon(
        onPressed: searching ? null : onSearch,
        icon: searching
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.manage_search_rounded),
        label: Text(searching ? l10n.pythonSearching : l10n.pythonFindAutomatically),
      );
    },
  );
}
