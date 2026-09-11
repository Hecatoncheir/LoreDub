// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/ocr_region.dart';
import '../theme.dart';

/// What a drag that starts at a point takes hold of.
enum _Grip {
  /// Outside the frame: a new frame is drawn from there.
  draw(SystemMouseCursors.precise),
  move(SystemMouseCursors.move),
  topLeft(SystemMouseCursors.resizeUpLeftDownRight),
  top(SystemMouseCursors.resizeUpDown),
  topRight(SystemMouseCursors.resizeUpRightDownLeft),
  right(SystemMouseCursors.resizeLeftRight),
  bottomRight(SystemMouseCursors.resizeUpLeftDownRight),
  bottom(SystemMouseCursors.resizeUpDown),
  bottomLeft(SystemMouseCursors.resizeUpRightDownLeft),
  left(SystemMouseCursors.resizeLeftRight);

  const _Grip(this.cursor);

  final MouseCursor cursor;

  bool get movesLeft => this == topLeft || this == left || this == bottomLeft;
  bool get movesRight => this == topRight || this == right || this == bottomRight;
  bool get movesTop => this == topLeft || this == top || this == topRight;
  bool get movesBottom => this == bottomLeft || this == bottom || this == bottomRight;
}

/// A scaled-down screen, shaped like the user's monitor, on which the frame
/// subtitle mode reads is drawn, moved and resized.
///
/// The frame only reaches [onChanged] once a drag ends, so storage is not
/// written on every pointer move. A null [onChanged] shows the frame
/// without letting it change, as every setting does while the pipeline runs.
class OcrRegionPicker extends StatefulWidget {
  const OcrRegionPicker({
    super.key,
    required this.region,
    required this.onChanged,
    required this.semanticLabel,
  });

  final OcrRegion region;
  final ValueChanged<OcrRegion>? onChanged;
  final String semanticLabel;

  @override
  State<OcrRegionPicker> createState() => _OcrRegionPickerState();
}

class _OcrRegionPickerState extends State<OcrRegionPicker> {
  /// How close to a corner or side, in logical pixels, grabs it.
  static const _gripReach = 10.0;

  /// How far one arrow press moves an edge, as a share of the window.
  static const _keyStep = 0.01;

  final _focusNode = FocusNode(debugLabel: 'ocrRegion');
  bool _focused = false;
  _Grip _hover = _Grip.draw;

  /// The frame while a drag is under way; null shows [OcrRegionPicker.region].
  OcrRegion? _draft;
  _Grip _grip = _Grip.draw;
  Offset _dragOrigin = Offset.zero;
  OcrRegion _dragStartRegion = OcrRegion.standard;

  bool get _enabled => widget.onChanged != null;
  OcrRegion get _shown => _draft ?? widget.region;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// The pointer as a fraction of the screen, kept on it.
  static Offset _fraction(Offset position, Size size) => Offset(
    (position.dx / size.width).clamp(0.0, 1.0),
    (position.dy / size.height).clamp(0.0, 1.0),
  );

  static _Grip _gripAt(Offset position, Size size, OcrRegion region) {
    final frame = Rect.fromLTRB(
      region.left * size.width,
      region.top * size.height,
      region.right * size.width,
      region.bottom * size.height,
    );
    bool near(Offset point) => (position - point).distance <= _gripReach;
    if (near(frame.topLeft)) return _Grip.topLeft;
    if (near(frame.topRight)) return _Grip.topRight;
    if (near(frame.bottomRight)) return _Grip.bottomRight;
    if (near(frame.bottomLeft)) return _Grip.bottomLeft;
    final withinX = position.dx >= frame.left && position.dx <= frame.right;
    final withinY = position.dy >= frame.top && position.dy <= frame.bottom;
    if (withinX && (position.dy - frame.top).abs() <= _gripReach) return _Grip.top;
    if (withinX && (position.dy - frame.bottom).abs() <= _gripReach) return _Grip.bottom;
    if (withinY && (position.dx - frame.left).abs() <= _gripReach) return _Grip.left;
    if (withinY && (position.dx - frame.right).abs() <= _gripReach) return _Grip.right;
    if (frame.contains(position)) return _Grip.move;
    return _Grip.draw;
  }

  void _onPanStart(DragStartDetails details, Size size) {
    _focusNode.requestFocus();
    _grip = _gripAt(details.localPosition, size, widget.region);
    _dragOrigin = _fraction(details.localPosition, size);
    _dragStartRegion = widget.region;
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    final point = _fraction(details.localPosition, size);
    final start = _dragStartRegion;
    setState(() {
      _draft = switch (_grip) {
        _Grip.draw => OcrRegion.fromCorners(_dragOrigin.dx, _dragOrigin.dy, point.dx, point.dy),
        _Grip.move => start.translated(point.dx - _dragOrigin.dx, point.dy - _dragOrigin.dy),
        final grip => start.withEdges(
          left: grip.movesLeft ? point.dx : null,
          right: grip.movesRight ? point.dx : null,
          top: grip.movesTop ? point.dy : null,
          bottom: grip.movesBottom ? point.dy : null,
        ),
      };
    });
  }

  void _onPanEnd() {
    final draft = _draft;
    if (draft == null) return;
    setState(() => _draft = null);
    if (draft != widget.region) widget.onChanged?.call(draft);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final (dx, dy) = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => (-_keyStep, 0.0),
      LogicalKeyboardKey.arrowRight => (_keyStep, 0.0),
      LogicalKeyboardKey.arrowUp => (0.0, -_keyStep),
      LogicalKeyboardKey.arrowDown => (0.0, _keyStep),
      _ => (0.0, 0.0),
    };
    if (dx == 0 && dy == 0) return KeyEventResult.ignored;
    final region = widget.region;
    final next = HardwareKeyboard.instance.isShiftPressed
        ? region.withEdges(right: region.right + dx, bottom: region.bottom + dy)
        : region.translated(dx, dy);
    if (next != region) widget.onChanged?.call(next);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final display = View.of(context).display.size;
    // A display that reports no size, as some test hosts do, gets the
    // commonest monitor shape rather than a division by zero.
    final aspectRatio = display.width > 0 && display.height > 0
        ? display.width / display.height
        : 16 / 9;
    return Semantics(
      label: widget.semanticLabel,
      enabled: _enabled,
      child: Focus(
        focusNode: _focusNode,
        canRequestFocus: _enabled,
        onKeyEvent: _onKey,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Opacity(
            opacity: _enabled ? 1 : 0.55,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: LoreDubPalette.graphite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _focused ? LoreDubPalette.orange : LoreDubPalette.graphite,
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: AspectRatio(
                      aspectRatio: aspectRatio,
                      child: LayoutBuilder(
                        builder: (context, box) => _screen(box.biggest),
                      ),
                    ),
                  ),
                ),
                // The stand, so the rectangle reads as a monitor at a glance.
                Container(width: 34, height: 14, color: LoreDubPalette.graphite),
                Container(
                  width: 120,
                  height: 6,
                  decoration: BoxDecoration(
                    color: LoreDubPalette.graphite,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _screen(Size size) {
    final painter = CustomPaint(
      key: const ValueKey('ocrRegionScreen'),
      size: size,
      painter: _RegionPainter(region: _shown, showGrips: _enabled),
    );
    if (!_enabled) return painter;
    return MouseRegion(
      cursor: _draft != null ? _grip.cursor : _hover.cursor,
      onHover: (event) {
        final grip = _gripAt(event.localPosition, size, widget.region);
        if (grip != _hover) setState(() => _hover = grip);
      },
      child: GestureDetector(
        // A corner is grabbed where the button went down, not where the
        // pointer had got to once the movement counted as a drag.
        dragStartBehavior: DragStartBehavior.down,
        onTapDown: (_) => _focusNode.requestFocus(),
        onPanStart: (details) => _onPanStart(details, size),
        onPanUpdate: (details) => _onPanUpdate(details, size),
        onPanEnd: (_) => _onPanEnd(),
        onPanCancel: _onPanEnd,
        child: painter,
      ),
    );
  }
}

class _RegionPainter extends CustomPainter {
  const _RegionPainter({required this.region, required this.showGrips});

  final OcrRegion region;
  final bool showGrips;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(screen, const Radius.circular(4)),
      Paint()..color = LoreDubPalette.ink,
    );

    // Two dim lines where games usually print dialogue, so the empty screen
    // suggests what to look for without pretending to be the game.
    final line = Paint()..color = LoreDubPalette.raised.withValues(alpha: 0.22);
    for (final (top, width) in [(0.82, 0.46), (0.88, 0.3)]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height * top),
            width: size.width * width,
            height: size.height * 0.035,
          ),
          const Radius.circular(3),
        ),
        line,
      );
    }

    final frame = Rect.fromLTRB(
      region.left * size.width,
      region.top * size.height,
      region.right * size.width,
      region.bottom * size.height,
    );
    // Dim everything the scan leaves out.
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(screen), Path()..addRect(frame)),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    canvas.drawRect(frame, Paint()..color = LoreDubPalette.orange.withValues(alpha: 0.16));
    canvas.drawRect(
      frame.deflate(1),
      Paint()
        ..color = LoreDubPalette.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (!showGrips) return;
    final fill = Paint()..color = LoreDubPalette.raised;
    final edge = Paint()
      ..color = LoreDubPalette.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final point in [
      frame.topLeft,
      frame.topCenter,
      frame.topRight,
      frame.centerRight,
      frame.bottomRight,
      frame.bottomCenter,
      frame.bottomLeft,
      frame.centerLeft,
    ]) {
      final grip = Rect.fromCenter(center: point, width: 9, height: 9);
      canvas
        ..drawRect(grip, fill)
        ..drawRect(grip, edge);
    }
  }

  @override
  bool shouldRepaint(covariant _RegionPainter oldDelegate) =>
      oldDelegate.region != region || oldDelegate.showGrips != showGrips;
}
