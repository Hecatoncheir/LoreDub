// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../common/dashboard_context.dart';
import '../theme.dart';

/// What the scene voices area says before anyone has been heard: that it
/// needs the converter, that it is listening, or how to start it.
class SceneVoicesEmpty extends StatelessWidget {
  const SceneVoicesEmpty({super.key, required this.listening});

  final bool listening;

  String _message(AppLocalizations l10n, {required bool tracksSpeakers}) {
    if (!tracksSpeakers) return l10n.sceneVoicesNeedsConverter;
    return listening ? l10n.sceneVoicesListening : l10n.sceneVoicesEmpty;
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
    child: Text(
      _message(
        AppLocalizations.of(context),
        tracksSpeakers: context.selection.tracksSpeakers,
      ),
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: listening ? context.colors.accent : context.colors.mutedInk),
    ),
  );
}
