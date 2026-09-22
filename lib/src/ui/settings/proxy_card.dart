// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/model_proxy.dart';
import '../common/setting_card.dart';
import 'bloc/settings_bloc.dart';
import 'settings_layout.dart';

/// The proxy the downloads go through. It is written down only once it
/// parses, so a half-typed address never reaches a download.
class ProxyCard extends StatefulWidget {
  const ProxyCard({super.key});

  @override
  State<ProxyCard> createState() => _ProxyCardState();
}

class _ProxyCardState extends State<ProxyCard> with AutomaticKeepAliveClientMixin {
  /// What is typed and not yet saved outlives the card being scrolled out
  /// of the list and back.
  @override
  bool get wantKeepAlive => true;

  final _form = GlobalKey<FormState>();
  late final TextEditingController _address;

  @override
  void initState() {
    super.initState();
    _address = TextEditingController(text: context.read<SettingsBloc>().settings.modelProxyUrl);
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    try {
      parseModelProxyUrl(value ?? '');
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final settings = context.read<SettingsBloc>();
    settings.add(SettingsChanged(settings.settings.copyWith(modelProxyUrl: _address.text.trim())));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final field = TextFormField(
      controller: _address,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: l10n.proxyLabel,
        hintText: 'http://127.0.0.1:7890',
        helperText: l10n.proxyHelper,
        helperMaxLines: 2,
        prefixIcon: const Icon(Icons.lan_outlined),
      ),
      validator: _validate,
      onFieldSubmitted: (_) => _save(),
    );
    final save = OutlinedButton.icon(
      onPressed: _save,
      icon: const Icon(Icons.save_outlined),
      label: Text(l10n.save),
    );
    return SettingCard(
      title: l10n.settingsModelDownloads,
      subtitle: l10n.proxyNote,
      child: Form(
        key: _form,
        child: LayoutBuilder(
          builder: (context, constraints) =>
              constraints.maxWidth < SettingsLayout.fieldBesideButtonWidth
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    field,
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: save),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: field),
                    const SizedBox(width: 16),
                    Padding(padding: const EdgeInsets.only(top: 4), child: save),
                  ],
                ),
        ),
      ),
    );
  }
}
