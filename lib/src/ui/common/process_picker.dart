// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/game_process.dart';

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
    final field = _MenuRoom(
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

/// Holds a dropdown's list to the room under its field.
///
/// Left to itself the list is as tall as all its entries — a machine runs
/// dozens of processes — and when that is more than the window has below
/// the field, the menu slides up over the field and hides what is being
/// typed into it. So the height is measured from where the field sits and
/// how tall the window is, and measured again when either changes.
class _MenuRoom extends StatefulWidget {
  const _MenuRoom({required this.builder});

  final Widget Function(double menuHeight) builder;

  @override
  State<_MenuRoom> createState() => _MenuRoomState();
}

class _MenuRoomState extends State<_MenuRoom> {
  /// Kept clear between the list and the bottom of the window.
  static const _margin = 16.0;

  /// A window too short for this lets the list overlap rather than become
  /// a slot two entries tall.
  static const _smallest = 160.0;
  static const _largest = 480.0;

  double? _room;

  @override
  Widget build(BuildContext context) {
    // Read so a resized window rebuilds this and measures again.
    final windowHeight = MediaQuery.sizeOf(context).height;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure(windowHeight));
    return widget.builder((_room ?? _largest).clamp(_smallest, _largest));
  }

  void _measure(double windowHeight) {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    final room = windowHeight - bottom - _margin;
    // A few pixels either way are not worth another frame.
    if (_room == null || (room - _room!).abs() > 4) setState(() => _room = room);
  }
}
