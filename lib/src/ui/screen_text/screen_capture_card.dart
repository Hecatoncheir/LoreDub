// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../common/module_label.dart';
import 'snapshot_controls.dart';

/// The game to read, the language on its screen, and the session's button.
class ScreenCaptureCard extends StatelessWidget {
  const ScreenCaptureCard({super.key});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModuleLabel(number: '01', label: AppLocalizations.of(context).areaScreenCapture),
          const SizedBox(height: 14),
          SnapshotControls(),
        ],
      ),
    ),
  );
}
