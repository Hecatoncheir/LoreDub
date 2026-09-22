// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../common/bloc/session_bloc.dart';
import '../theme.dart';

/// The press that starts or ends listening for the voices of a scene, drawn
/// orange while it listens.
class SceneListenToggle extends StatelessWidget {
  const SceneListenToggle({
    super.key,
    required this.listening,
    required this.enabled,
    required this.initializing,
  });

  final bool listening;
  final bool enabled;
  final bool initializing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextButton.icon(
      key: const ValueKey('sceneListen'),
      onPressed: enabled
          ? () => context.read<SessionBloc>().add(SceneToggled(initializing: initializing))
          : null,
      icon: Icon(listening ? Icons.stop_rounded : Icons.hearing_rounded, size: 18),
      label: Text(listening ? l10n.sceneVoicesListenStop : l10n.sceneVoicesListen),
      style: TextButton.styleFrom(
        foregroundColor: listening ? context.colors.accent : context.colors.ink,
      ),
    );
  }
}
