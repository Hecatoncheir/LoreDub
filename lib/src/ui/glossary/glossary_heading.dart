// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../common/module_number.dart';

/// The heading of a list, in the vocabulary the other screens use.
class GlossaryHeading extends StatelessWidget {
  const GlossaryHeading({super.key, required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ModuleNumber(number),
      const SizedBox(width: 10),
      Text(label, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}
