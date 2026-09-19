// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/game_process.dart';
import 'menu_room.dart';

/// Which game to listen to.
///
/// Three screens ask the same question — Live, the character recording and
/// the node graph — so the field is one widget rather than a menu copied
/// about, and every one of them filters as it is typed into, names each
/// process with its pid so two `conhost.exe` can be told apart, and lists
/// the most recently started first, which is almost always the game.
class ProcessPicker extends StatelessWidget {
  const ProcessPicker({
    super.key,
    required this.processes,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    this.onRefresh,
  });

  /// In the order the engine listed them, which is newest first.
  final List<GameProcess> processes;
  final GameProcess? selected;
  final ValueChanged<GameProcess?> onSelected;

  /// A running session holds the process it started with, so the field is
  /// closed while one is up.
  final bool enabled;

  /// Lists the processes again, for a game started after the screen was
  /// opened. No button is drawn when nothing is passed.
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final field = MenuRoom(
      builder: (menuHeight) => DropdownMenu<GameProcess>(
        // Keyed by the selection: it can be changed from another screen, and
        // the field keeps what it was built with otherwise.
        key: ValueKey(selected?.pid),
        initialSelection: selected,
        expandedInsets: EdgeInsets.zero,
        menuHeight: menuHeight,
        enabled: enabled,
        enableFilter: true,
        enableSearch: true,
        requestFocusOnTap: true,
        // A narrow field must not break the label mid-word: it is cut short
        // instead, which still reads as the beginning of the right words.
        label: Text(
          l10n.processLabel,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
        hintText: l10n.processHint,
        inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(hintMaxLines: 1),
        dropdownMenuEntries: [
          for (final process in processes)
            DropdownMenuEntry(
              value: process,
              label: l10n.processEntry(process.name, process.pid),
            ),
        ],
        onSelected: enabled ? onSelected : null,
      ),
    );
    if (onRefresh == null) return field;
    // Refreshing belongs to the picker, so it travels with it wherever the
    // field goes rather than sitting on a row of its own.
    return Row(
      children: [
        Expanded(child: field),
        const SizedBox(width: 12),
        IconButton.outlined(
          tooltip: l10n.refreshProcesses,
          onPressed: enabled ? onRefresh : null,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}
