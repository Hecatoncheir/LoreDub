// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

/// Holds a dropdown's list to the room under its field.
///
/// Left to itself the list is as tall as all its entries — a machine runs
/// dozens of processes — and when that is more than the window has below
/// the field, the menu slides up over the field and hides what is being
/// typed into it. So the height is measured from where the field sits and
/// how tall the window is, and measured again when either changes.
class MenuRoom extends StatefulWidget {
  const MenuRoom({super.key, required this.builder});

  final Widget Function(double menuHeight) builder;

  @override
  State<MenuRoom> createState() => _MenuRoomState();
}

class _MenuRoomState extends State<MenuRoom> {
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
