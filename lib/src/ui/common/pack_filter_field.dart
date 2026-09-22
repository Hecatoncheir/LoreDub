// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// The field a shelf of packs is narrowed by, over the packs it narrows: the
/// cast's and the glossary's alike.
///
/// What is typed is kept by the shelf rather than by the field, in
/// [controller]: a pack the player makes or loads is one they mean to see,
/// so the shelf empties the field then, and a filter it could not reach
/// would hide the new pack behind what was typed for another.
class PackFilterField extends StatelessWidget {
  const PackFilterField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, typed, _) => TextField(
        controller: controller,
        decoration: InputDecoration(
          isDense: true,
          hintText: l10n.packsFilter,
          prefixIcon: const Icon(Icons.filter_list_rounded, size: 18),
          suffixIcon: typed.text.isEmpty
              ? null
              : IconButton(
                  tooltip: l10n.packsFilterClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: controller.clear,
                ),
        ),
      ),
    );
  }
}
