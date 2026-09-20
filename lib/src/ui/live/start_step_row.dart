// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../theme.dart';

/// One line of the checklist: its place in the list, what is missing, and
/// the screen it is put right on.
class StartStepRow extends StatelessWidget {
  const StartStepRow({
    super.key,
    required this.number,
    required this.title,
    required this.action,
    required this.onPressed,
  });

  final int number;
  final String title;
  final String? action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      children: [
        SizedBox(
          width: 30,
          child: Text(
            '$number.',
            style: TextStyle(
              fontFamily: LoreDubFonts.mono,
              color: context.colors.mutedInk,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        // A step is a line and no more: three of them with a paragraph
        // each left the transcript under the card nothing to stand in.
        Expanded(child: Text(title)),
        if (action case final label?) ...[
          const SizedBox(width: 12),
          TextButton(onPressed: onPressed, child: Text(label)),
        ],
      ],
    ),
  );
}
