// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/model_package.dart';
import '../failure_messages.dart';
import '../model_names.dart';
import '../theme.dart';

/// A download that failed. Its model went back to "not downloaded", so its
/// own button tries again; the reason needs more room than a card has.
class ModelFailureRow extends StatelessWidget {
  const ModelFailureRow({super.key, required this.state});

  final ModelInstallState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: ValueKey('modelFailure-${state.model.id}'),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: context.colors.panel,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(color: context.colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(modelTitle(l10n, state.model), style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          SelectableText(
            describeFailure(l10n, state.error!),
            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
