// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/model_package.dart';
import '../compute_names.dart';
import '../model_names.dart';
import '../theme.dart';
import 'model_visuals.dart';

/// The Whisper builds drawn as a chart: each model is a bar whose height is
/// its download to scale and whose place along the bottom is how well it
/// hears speech, so the trade being made — disk and time for accuracy — is
/// the picture itself.
///
/// A bar also carries the model's state: light while it is not downloaded,
/// light with a tick once it is, dark with an orange edge when it is the one
/// in use, and filling up from the bottom while it downloads. Its buttons are
/// always there — download, pause or resume and cancel, or delete — so what
/// can be done with a model never waits for a hover to be found.
class WhisperModelChart extends StatelessWidget {
  const WhisperModelChart({
    super.key,
    required this.models,
    required this.selectedId,
    required this.running,
    required this.isStopping,
    required this.onInstall,
    required this.onPause,
    required this.onCancel,
    required this.onRemove,
    required this.onSelect,
  });

  /// Below this the bars cannot hold their names; the screen lists the
  /// models as cards instead.
  static const minimumWidth = 660.0;

  final List<ModelInstallState> models;
  final String? selectedId;

  /// Dubbing is on: the model in use can be neither swapped nor deleted.
  final bool running;

  /// A stop has been asked for and the download has not noticed yet.
  final bool Function(String id) isStopping;

  /// Starts a download, or resumes a paused one.
  final void Function(ModelInstallState state) onInstall;
  final void Function(ModelInstallState state) onPause;
  final void Function(ModelInstallState state) onCancel;

  /// Deletes a downloaded model; asked only once the reader has confirmed.
  final void Function(ModelInstallState state) onRemove;

  /// Null while dubbing runs.
  final void Function(ModelInstallState state)? onSelect;

  static const _labelGutter = 86.0;
  static const _titleBand = 30.0;
  static const _plotHeight = 400.0;
  static const _qualityBand = 42.0;
  static const _axisTitleWidth = 96.0;
  static const _gap = 22.0;
  static const _minBarWidth = 92.0;
  static const _minBarHeight = 96.0;
  static const _labelSpacing = 17.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failed = [
      for (final state in models)
        if (state.error != null) state,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => _chart(context, l10n, constraints.maxWidth),
        ),
        const SizedBox(height: 14),
        _Legend(l10n: l10n),
        for (final state in failed) ...[
          const SizedBox(height: 10),
          ModelFailureRow(state: state),
        ],
      ],
    );
  }

  Widget _chart(BuildContext context, AppLocalizations l10n, double width) {
    final count = models.length;
    const left = _labelGutter;
    final right = width - _axisTitleWidth;
    const baseline = _titleBand + _plotHeight;
    // Wider for the better models, as the reference drawing has them; the
    // width says nothing on its own, so it is a rank and not a measure.
    final weights = [for (var index = 0; index < count; index++) 10 + 6.5 * index];
    final weightSum = weights.fold<double>(0, (sum, weight) => sum + weight);
    final room = math.max(0.0, right - left - _gap * (count + 1));
    final largest = models.fold<int>(1, (most, state) => math.max(most, state.model.downloadBytes));
    // A little headroom, so the largest bar does not touch the top.
    final scale = _plotHeight / (largest * 1.08);
    final bars = <Rect>[];
    var x = left + _gap;
    for (var index = 0; index < count; index++) {
      final barWidth = math.max(_minBarWidth, room * weights[index] / weightSum);
      final height = math.max(_minBarHeight, models[index].model.downloadBytes * scale);
      bars.add(Rect.fromLTWH(x, baseline - height, barWidth, height));
      x += barWidth + _gap;
    }

    // A size is written at the height of its bar. The three larger builds
    // weigh nearly the same, so labels that would overlap are pushed up
    // just enough to be read, starting from the lowest.
    final labelCentres = List<double>.filled(count, 0);
    final lowestFirst = [for (var index = 0; index < count; index++) index]
      ..sort((a, b) => bars[b].top.compareTo(bars[a].top));
    double? previous;
    for (final index in lowestFirst) {
      var centre = bars[index].top;
      if (previous != null) centre = math.min(centre, previous - _labelSpacing);
      labelCentres[index] = centre;
      previous = centre;
    }

    const axisTitle = TextStyle(
      fontFamily: LoreDubFonts.mono,
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: LoreDubPalette.orangeDark,
    );
    const marking = TextStyle(
      fontFamily: LoreDubFonts.mono,
      fontSize: 12,
      color: LoreDubPalette.ink,
    );

    return SizedBox(
      height: baseline + _qualityBand,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _AxesPainter(
                left: left,
                top: _titleBand - 12,
                baseline: baseline,
                right: width - 8,
                bars: bars,
              ),
            ),
          ),
          Positioned(
            left: 0,
            width: left - 10,
            top: 0,
            child: Text(l10n.whisperAxisSize, textAlign: TextAlign.right, style: axisTitle),
          ),
          Positioned(
            left: 0,
            width: left - 10,
            top: baseline + 4,
            child: const Text('0', textAlign: TextAlign.right, style: marking),
          ),
          Positioned(
            right: 0,
            width: _axisTitleWidth - 8,
            top: baseline + 10,
            child: Text(l10n.whisperAxisQuality, textAlign: TextAlign.right, style: axisTitle),
          ),
          for (var index = 0; index < count; index++) ...[
            Positioned(
              left: 0,
              width: left - 10,
              top: labelCentres[index] - 8,
              child: Text(
                formatPackageSize(models[index].model.downloadBytes),
                textAlign: TextAlign.right,
                style: marking,
              ),
            ),
            Positioned(
              left: bars[index].left,
              width: bars[index].width,
              top: baseline + 10,
              child: Text(
                recognitionQualityName(l10n, models[index].model.quality) ?? '',
                textAlign: TextAlign.center,
                style: marking,
              ),
            ),
            Positioned.fromRect(
              rect: bars[index],
              child: _ModelBar(
                key: ValueKey('whisperBar-${models[index].model.id}'),
                state: models[index],
                selected: models[index].model.id == selectedId,
                tooltip: _tooltip(l10n, models[index]),
                onTap: _tapFor(models[index]),
                actions: _actionsFor(context, l10n, models[index]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  VoidCallback? _tapFor(ModelInstallState state) {
    if (state.progress != null) return null;
    if (!state.installed) return () => onInstall(state);
    final select = onSelect;
    if (state.model.id == selectedId || select == null) return null;
    return () => select(state);
  }

  List<ModelAction> _actionsFor(
    BuildContext context,
    AppLocalizations l10n,
    ModelInstallState state,
  ) => modelActions(
    l10n: l10n,
    parts: [state],
    isStopping: isStopping,
    // The model a live session reads from cannot vanish under it.
    locked: running && state.model.id == selectedId,
    onInstall: onInstall,
    onPause: onPause,
    onCancel: onCancel,
    onRemove: () async {
      final confirmed = await confirmModelRemoval(
        context,
        title: l10n.modelRemoveTitle,
        message: l10n.modelRemoveMessage(
          modelTitle(l10n, state.model),
          formatPackageSize(state.model.downloadBytes),
        ),
      );
      if (confirmed) onRemove(state);
    },
  );

  String _tooltip(AppLocalizations l10n, ModelInstallState state) {
    final model = state.model;
    final progress = state.progress;
    return [
      modelTitle(l10n, model),
      modelDescription(l10n, model),
      if (progress != null)
        l10n.whisperDownloadProgress(
          (progress * 100).round(),
          formatPackageSize((model.downloadBytes * progress).round()),
          formatPackageSize(model.downloadBytes),
        )
      else if (!state.installed)
        l10n.whisperHintDownload(formatPackageSize(model.downloadBytes))
      else if (model.id == selectedId)
        l10n.whisperHintSelected
      else if (onSelect == null)
        l10n.whisperHintLocked
      else
        l10n.whisperHintSelect,
    ].join('\n');
  }
}

/// One model. It grows a little under the pointer, from the axis up, so the
/// bar about to be clicked stands out without the chart shifting around it.
class _ModelBar extends StatefulWidget {
  const _ModelBar({
    super.key,
    required this.state,
    required this.selected,
    required this.tooltip,
    required this.onTap,
    required this.actions,
  });

  final ModelInstallState state;
  final bool selected;
  final String tooltip;
  final VoidCallback? onTap;
  final List<ModelAction> actions;

  @override
  State<_ModelBar> createState() => _ModelBarState();
}

class _ModelBarState extends State<_ModelBar> {
  static const _hoverScale = 1.04;
  static const _actionBand = 40.0;

  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = widget.state;
    final progress = state.progress;
    final downloading = progress != null;
    final inUse = widget.selected && state.installed && !downloading;
    final marked = downloading || widget.selected;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final bar = Material(
      color: inUse ? LoreDubPalette.graphite : LoreDubPalette.panel,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        side: BorderSide(
          color: marked
              ? LoreDubPalette.orange
              : _hovered
              ? LoreDubPalette.ink
              : LoreDubPalette.outline,
          width: marked ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: widget.onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The buttons sit at the foot of the bar, where the fill of a
            // download arrives first; they switch to light once it is dark.
            final darkFoot =
                inUse || (progress != null && progress * constraints.maxHeight >= _actionBand);
            return Stack(
              fit: StackFit.expand,
              children: [
                if (progress != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 300),
                      heightFactor: progress.clamp(0.0, 1.0),
                      widthFactor: 1,
                      child: const ColoredBox(color: LoreDubPalette.graphite),
                    ),
                  ),
                Column(
                  children: [
                    // Turbo only suits an English original, and that should
                    // not wait for a tooltip to be found.
                    if (!state.model.translatesSpeech)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                        child: Text(
                          l10n.whisperNoTranslation,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: LoreDubFonts.mono,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: inUse ? LoreDubPalette.orange : LoreDubPalette.orangeDark,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Tooltip(
                        message: widget.tooltip,
                        waitDuration: const Duration(milliseconds: 400),
                        child: SizedBox.expand(child: Center(child: _content(l10n, inUse))),
                      ),
                    ),
                    SizedBox(
                      height: _actionBand,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final action in widget.actions)
                            ModelActionButton(action: action, onDark: darkFoot),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? _hoverScale : 1,
        alignment: Alignment.bottomCenter,
        duration: still ? Duration.zero : const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: Semantics(
          button: widget.onTap != null,
          selected: widget.selected,
          label: modelTitle(l10n, state.model),
          child: bar,
        ),
      ),
    );
  }

  Widget _content(AppLocalizations l10n, bool inUse) => LayoutBuilder(
    builder: (context, constraints) {
      final state = widget.state;
      final progress = state.progress;
      final roomy = constraints.maxWidth >= 150;
      final children = <Widget>[];
      if (progress != null && !roomy) {
        // A narrow bar has room for the ring or for words, not both: the
        // ring and its figure win, the pause shows as a dimmed arc and the
        // play button, and the name returns once the download is done.
        final dial = math.min(
          116.0,
          math.min(constraints.maxWidth * 0.62, constraints.maxHeight * 0.92),
        );
        return Center(
          child: ModelProgressDial(
            key: ValueKey('whisperDial-${state.model.id}'),
            progress: progress,
            paused: state.paused,
            size: dial,
          ),
        );
      }
      if (progress != null) {
        final dial = math.min(
          116.0,
          math.min(constraints.maxWidth * 0.62, constraints.maxHeight * 0.62),
        );
        children.add(
          ModelProgressDial(
            key: ValueKey('whisperDial-${state.model.id}'),
            progress: progress,
            paused: state.paused,
            size: dial,
          ),
        );
        if (state.paused) {
          children
            ..add(const SizedBox(height: 4))
            ..add(
              Text(
                l10n.downloadPaused,
                style: const TextStyle(
                  fontFamily: LoreDubFonts.mono,
                  fontSize: 11,
                  color: LoreDubPalette.orange,
                ),
              ),
            );
        }
      } else {
        children.add(
          Icon(
            state.installed ? Icons.cloud_done_outlined : Icons.cloud_download_outlined,
            size: roomy ? 34 : 24,
            color: inUse || !state.installed ? LoreDubPalette.orange : LoreDubPalette.ink,
          ),
        );
      }
      children
        ..add(const SizedBox(height: 8))
        ..add(
          Text(
            whisperShortName(state.model),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: LoreDubFonts.mono,
              fontSize: roomy ? 20 : 15,
              fontWeight: FontWeight.w500,
              color: progress != null
                  ? LoreDubPalette.orange
                  : inUse
                  ? LoreDubPalette.raised
                  : LoreDubPalette.ink,
            ),
          ),
        );
      return Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      );
    },
  );
}

/// What the four looks of a bar mean. Light, ticked, dark and filling are
/// not self-evident, and a player should not have to learn them by trying.
class _Legend extends StatelessWidget {
  const _Legend({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    Widget swatch({required Color fill, required Color edge, double filled = 1, IconData? icon}) =>
        Container(
          width: 16,
          height: 16,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: LoreDubPalette.panel,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
            border: Border.all(color: edge, width: edge == LoreDubPalette.orange ? 2 : 1),
          ),
          child: icon != null
              ? Icon(icon, size: 11, color: fill)
              : Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: filled,
                    widthFactor: 1,
                    child: ColoredBox(color: fill),
                  ),
                ),
        );
    Widget item(Widget mark, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: LoreDubFonts.mono,
            fontSize: 11,
            color: LoreDubPalette.mutedInk,
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(left: WhisperModelChart._labelGutter),
      child: Wrap(
        spacing: 20,
        runSpacing: 8,
        children: [
          item(
            swatch(
              fill: LoreDubPalette.orange,
              edge: LoreDubPalette.outline,
              icon: Icons.cloud_download_outlined,
            ),
            l10n.whisperLegendMissing,
          ),
          item(
            swatch(
              fill: LoreDubPalette.ink,
              edge: LoreDubPalette.outline,
              icon: Icons.cloud_done_outlined,
            ),
            l10n.whisperLegendInstalled,
          ),
          item(
            swatch(fill: LoreDubPalette.graphite, edge: LoreDubPalette.orange),
            l10n.whisperLegendSelected,
          ),
          item(
            swatch(fill: LoreDubPalette.graphite, edge: LoreDubPalette.orange, filled: 0.5),
            l10n.whisperLegendDownloading,
          ),
        ],
      ),
    );
  }
}

class _AxesPainter extends CustomPainter {
  const _AxesPainter({
    required this.left,
    required this.top,
    required this.baseline,
    required this.right,
    required this.bars,
  });

  final double left;
  final double top;
  final double baseline;
  final double right;
  final List<Rect> bars;

  @override
  void paint(Canvas canvas, Size size) {
    final guide = Paint()
      ..color = LoreDubPalette.ink.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (final bar in bars) {
      // From the size on the axis to the top of its bar...
      _dash(canvas, Offset(left, bar.top), Offset(bar.left - 2, bar.top), guide);
      // ...and from the bar's edge down to its quality.
      _dash(canvas, Offset(bar.right, baseline), Offset(bar.right, baseline + 28), guide);
    }
    final axis = Paint()
      ..color = LoreDubPalette.orange
      ..strokeWidth = 2;
    canvas
      ..drawLine(Offset(left, top), Offset(left, baseline), axis)
      ..drawLine(Offset(left, baseline), Offset(right, baseline), axis);
  }

  static void _dash(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dash = 5.0;
    const gap = 4.0;
    final length = (to - from).distance;
    if (length <= 0) return;
    final step = (to - from) / length;
    for (var travelled = 0.0; travelled < length; travelled += dash + gap) {
      final end = math.min(travelled + dash, length);
      canvas.drawLine(from + step * travelled, from + step * end, paint);
    }
  }

  @override
  bool shouldRepaint(_AxesPainter oldDelegate) =>
      oldDelegate.left != left ||
      oldDelegate.top != top ||
      oldDelegate.baseline != baseline ||
      oldDelegate.right != right ||
      !_sameBars(oldDelegate.bars, bars);

  static bool _sameBars(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}
