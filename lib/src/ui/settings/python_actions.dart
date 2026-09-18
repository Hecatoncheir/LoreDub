// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

/// The buttons under the Python path: a row while they fit, a stack of one
/// width when they do not.
class PythonActions extends StatelessWidget {
  const PythonActions({super.key, required this.children});

  final List<Widget> children;

  /// Below this the three of them no longer share a line.
  static const _oneRow = 520.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth >= _oneRow
        ? Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: children,
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, child) in children.indexed) ...[
                if (index > 0) const SizedBox(height: 8),
                child,
              ],
            ],
          ),
  );
}
