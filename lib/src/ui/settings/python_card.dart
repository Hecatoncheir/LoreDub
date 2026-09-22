// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../data/repositories/system_repository.dart';
import '../common/setting_card.dart';
import 'bloc/settings_bloc.dart';
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
    final chosen = context.read<SettingsBloc>().settings.pythonExecutable;
    _path = TextEditingController(
      text: chosen.isEmpty ? context.read<SystemRepository>().bundledPython : chosen,
    );
  }

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  /// What the search finds is written to the settings; the field picks it
  /// up from there (the listener in [build]), as it would a path written by
  /// anything else.
  void _find() => context.read<SettingsBloc>().add(const PythonSearched());

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final settings = context.read<SettingsBloc>();
    settings.add(SettingsChanged(settings.settings.copyWith(pythonExecutable: _path.text.trim())));
  }

  void _useBundled() {
    _path.text = context.read<SystemRepository>().bundledPython;
    _save();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    return BlocListener<SettingsBloc, SettingsState>(
      listenWhen: (was, now) =>
          was.settings.pythonExecutable != now.settings.pythonExecutable &&
          now.settings.pythonExecutable.isNotEmpty,
      listener: (context, state) => _path.text = state.settings.pythonExecutable,
      child: SettingCard(
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
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? l10n.pythonFieldRequired : null,
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
      ),
    );
  }
}
