// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../domain/model_package.dart';
import '../../../l10n/app_localizations.dart';
import 'model_card_details.dart';

/// One package as a card: what it is, how far its download has got, and the
/// button that fetches it. Only the Whisper builds are drawn this way now, in
/// a window too narrow for their chart.
class ModelCard extends StatelessWidget {
  const ModelCard({
    super.key,
    required this.state,
    required this.onInstall,
    required this.onPause,
    required this.onCancel,
    this.stopping = false,
    this.choosable = false,
    this.selected = false,
    this.onSelect,
  });

  final ModelInstallState state;
  final VoidCallback onInstall;

  /// Stopping keeps what arrived; cancelling throws it away.
  final VoidCallback onPause;
  final VoidCallback onCancel;

  /// A stop has been asked for and the download has not noticed yet.
  final bool stopping;

  /// Whether this card is one of a set the player picks between. Only the
  /// Whisper builds are drawn as cards now, in a window too narrow for
  /// their chart; such a card shows which one is chosen.
  final bool choosable;
  final bool selected;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final details = ModelCardDetails(
      state: state,
      stopping: stopping,
      choosable: choosable,
      selected: selected,
      onInstall: onInstall,
      onPause: onPause,
      onCancel: onCancel,
    );
    final action = OutlinedButton.icon(
      onPressed: state.installed || state.stoppable ? null : onInstall,
      icon: Icon(state.installed ? Icons.check_rounded : Icons.download_rounded),
      label: Text(state.installed ? l10n.modelInstalled : l10n.modelDownload),
    );
    final body = Padding(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 600
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  details,
                  const SizedBox(height: 16),
                  Align(alignment: Alignment.centerRight, child: action),
                ],
              )
            : Row(
                children: [
                  Expanded(child: details),
                  const SizedBox(width: 20),
                  action,
                ],
              ),
      ),
    );
    return Card(
      // The whole card picks the build, not just the small indicator.
      child: onSelect == null
          ? body
          : InkWell(onTap: onSelect, borderRadius: BorderRadius.circular(12), child: body),
    );
  }
}
