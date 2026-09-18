// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../common/module_label.dart';

/// One of the two areas at the foot of the settings: its marking, spaced so
/// that both of them start on the same line, and its cards under it.
class SettingsArea extends StatelessWidget {
  const SettingsArea({
    super.key,
    required this.number,
    required this.label,
    required this.children,
  });

  final String number;
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ModuleLabel(number: number, label: label),
      ),
      ...children,
    ],
  );
}
