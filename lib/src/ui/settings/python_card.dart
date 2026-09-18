// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/runtime_paths.dart';
import '../common/setting_card.dart';
import '../dashboard/cubits/settings_cubit.dart';
import 'python_actions.dart';
import 'python_search_button.dart';

/// Where the interpreter the worker runs under sits: typed in, found by a
/// search, or put back to the one the installer brought.
class PythonCard extends StatefulWidget {
  const PythonCard({super.key});

  @override
  State<PythonCard> createState() => _PythonCardState();
}

class _PythonCardState extends State<PythonCard> with AutomaticKeepAliveClientMixin {
  /// What is typed and not yet saved outlives the card being scrolled out
  /// of the list and back.
  @override
  bool get wantKeepAlive => true;

  final _form = GlobalKey<FormState>();
  late final TextEditingController _path;

  @override
  void initState() {
    super.initState();
    final chosen = context.read<SettingsCubit>().settings.pythonExecutable;
    _path = TextEditingController(text: chosen.isEmpty ? bundledPythonExecutablePath() : chosen);
  }

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    final executable = await context.read<SettingsCubit>().findPythonExecutable();
    if (executable == null || !mounted) return;
    _path.text = executable;
  }

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final settings = context.read<SettingsCubit>();
    settings.update(settings.settings.copyWith(pythonExecutable: _path.text.trim()));
  }

  void _useBundled() {
    _path.text = bundledPythonExecutablePath();
    _save();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    return SettingCard(
      title: l10n.settingsPython,
      subtitle: l10n.pythonNote,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _path,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.pythonFieldLabel,
                helperText: l10n.pythonFieldHelper,
                prefixIcon: const Icon(Icons.terminal_rounded),
              ),
              validator: (value) => (value ?? '').trim().isEmpty ? l10n.pythonFieldRequired : null,
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            // Side by side where the card is wide enough for all three, and
            // one under another at a shared width where it is not: wrapped at
            // their own widths they came out ragged, each button a different
            // length down the right edge.
            PythonActions(
              children: [
                PythonSearchButton(onSearch: _find),
                OutlinedButton.icon(
                  onPressed: _useBundled,
                  icon: const Icon(Icons.settings_backup_restore_rounded),
                  label: Text(l10n.pythonBundled),
                ),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(l10n.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
