// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/language_pair.dart';
import '../../domain/model_package.dart';
import '../compute_names.dart';
import '../language_names.dart';
import '../model_names.dart';
import '../theme.dart';
import 'model_visuals.dart';

/// Tiles in as many equal columns as fit, left-aligned so a lone tile keeps
/// the size of its neighbours in the section above.
class ModelTileGrid extends StatelessWidget {
  const ModelTileGrid({super.key, required this.children});

  static const _minWidth = 200.0;
  static const _gap = 14.0;
  static const _height = 196.0;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = math.max(1, ((constraints.maxWidth + _gap) / (_minWidth + _gap)).floor());
      final width = ((constraints.maxWidth - _gap * (columns - 1)) / columns).floorToDouble();
      return Wrap(
        spacing: _gap,
        runSpacing: _gap,
        children: [
          for (final child in children) SizedBox(width: width, height: _height, child: child),
        ],
      );
    },
  );
}

/// One line of what a tile holds: "translation · 461 MB", ticked once it
/// is on disk.
class ModelTilePart {
  const ModelTilePart({required this.label, required this.bytes, required this.installed});

  final String label;
  final int bytes;
  final bool installed;
}

/// A model, or a pair of them, drawn in the Whisper bars' vocabulary:
/// light while missing, a cloud with a tick once downloaded, graphite with
/// an orange edge in use, filling from the bottom with a ring while it
/// downloads, its buttons always at its foot.
class ModelTile extends StatelessWidget {
  const ModelTile({
    super.key,
    required this.title,
    required this.parts,
    required this.progress,
    required this.paused,
    required this.installed,
    required this.inUse,
    required this.marked,
    required this.tooltip,
    required this.onTap,
    required this.actions,
  });

  final String title;
  final List<ModelTilePart> parts;
  final double? progress;
  final bool paused;
  final bool installed;

  /// Downloaded and in use: the dark face.
  final bool inUse;

  /// Chosen, downloaded or not: the orange edge.
  final bool marked;
  final String tooltip;
  final VoidCallback? onTap;
  final List<ModelAction> actions;

  static const _actionBand = 44.0;

  @override
  Widget build(BuildContext context) => HoverGrow(
    alignment: Alignment.center,
    scale: 1.03,
    builder: (context, hovered) {
      final value = progress;
      final edged = marked || value != null;
      // Orange is the one colour that reads on the light face and on the
      // dark fill rising behind the words.
      final ink = value != null
          ? LoreDubPalette.orange
          : inUse
          ? LoreDubPalette.raised
          : LoreDubPalette.ink;
      return Semantics(
        button: onTap != null,
        selected: marked,
        label: title,
        child: Material(
          color: inUse ? LoreDubPalette.graphite : LoreDubPalette.panel,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            side: BorderSide(
              color: edged
                  ? LoreDubPalette.orange
                  : hovered
                  ? LoreDubPalette.ink
                  : LoreDubPalette.outline,
              width: edged ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final darkFoot =
                    inUse || (value != null && value * constraints.maxHeight >= _actionBand);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (value != null)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: AnimatedFractionallySizedBox(
                          duration: const Duration(milliseconds: 300),
                          heightFactor: value.clamp(0.0, 1.0),
                          widthFactor: 1,
                          child: const ColoredBox(color: LoreDubPalette.graphite),
                        ),
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Tooltip(
                          message: tooltip,
                          waitDuration: const Duration(milliseconds: 400),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 12, 0),
                            child: _heading(ink),
                          ),
                        ),
                        Expanded(
                          child: value == null
                              ? const SizedBox.shrink()
                              : LayoutBuilder(
                                  builder: (context, room) => Center(
                                    child: ModelProgressDial(
                                      progress: value,
                                      paused: paused,
                                      size: math.max(
                                        28,
                                        math.min(
                                          76,
                                          math.min(room.maxHeight - 6, room.maxWidth * 0.6),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        SizedBox(
                          height: _actionBand,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (final action in actions)
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
        ),
      );
    },
  );

  Widget _heading(Color ink) {
    final detail = TextStyle(fontFamily: LoreDubFonts.mono, fontSize: 11, color: ink);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: LoreDubFonts.display,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
            ),
            if (progress == null)
              Icon(
                installed ? Icons.cloud_done_outlined : Icons.cloud_download_outlined,
                size: 22,
                color: inUse || !installed ? LoreDubPalette.orange : LoreDubPalette.ink,
              ),
          ],
        ),
        const SizedBox(height: 10),
        for (final part in parts)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  part.installed ? Icons.check_rounded : Icons.remove_rounded,
                  size: 14,
                  color: part.installed
                      ? (inUse ? LoreDubPalette.orange : LoreDubPalette.success)
                      : ink.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(part.label, style: detail)),
                Text(formatPackageSize(part.bytes), style: detail),
              ],
            ),
          ),
      ],
    );
  }
}

/// A dubbing language: its translator and voice as one tile, downloaded,
/// picked and deleted together.
class LanguagePairTile extends StatelessWidget {
  const LanguagePairTile({
    super.key,
    required this.pair,
    required this.selected,
    required this.running,
    required this.isStopping,
    required this.onSelect,
    required this.onInstall,
    required this.onPause,
    required this.onCancel,
    required this.onRemove,
  });

  final LanguagePair pair;
  final bool selected;

  /// Dubbing is on: the language in use can be neither swapped nor deleted.
  final bool running;
  final bool Function(String id) isStopping;

  /// Null while dubbing runs.
  final VoidCallback? onSelect;
  final void Function(ModelInstallState state) onInstall;
  final void Function(ModelInstallState state) onPause;
  final void Function(ModelInstallState state) onCancel;
  final void Function(ModelInstallState state) onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = spokenLanguageName(l10n, pair.language);
    final progress = pair.progress;
    return ModelTile(
      title: name,
      parts: [
        if (pair.translation case final translation?)
          ModelTilePart(
            label: l10n.modelPartTranslation,
            bytes: translation.model.downloadBytes,
            installed: translation.installed,
          ),
        if (pair.speech case final speech?)
          ModelTilePart(
            label: l10n.modelPartVoice,
            bytes: speech.model.downloadBytes,
            installed: speech.installed,
          ),
      ],
      progress: progress,
      paused: pair.paused,
      installed: pair.installed,
      inUse: selected && pair.installed && progress == null,
      marked: selected,
      tooltip: [
        for (final part in pair.parts) modelTitle(l10n, part.model),
        if (progress != null)
          _progressLine(l10n, progress, pair.downloadBytes)
        else if (selected)
          l10n.languageHintSelected
        else if (onSelect == null)
          l10n.languageHintLocked
        else
          l10n.languageHintSelect,
      ].join('\n'),
      onTap: selected ? null : onSelect,
      actions: modelActions(
        l10n: l10n,
        parts: pair.parts,
        isStopping: isStopping,
        locked: running && selected,
        onInstall: onInstall,
        onPause: onPause,
        onCancel: onCancel,
        onRemove: () async {
          final confirmed = await confirmModelRemoval(
            context,
            title: l10n.languageRemoveTitle,
            message: l10n.languageRemoveMessage(name, formatPackageSize(pair.downloadBytes)),
          );
          if (!confirmed) return;
          for (final part in pair.parts) {
            if (part.installed) onRemove(part);
          }
        },
      ),
    );
  }
}

/// The OpenVoice converter: one package, in use whenever the original voice
/// is on.
class ConverterTile extends StatelessWidget {
  const ConverterTile({
    super.key,
    required this.state,
    required this.inUse,
    required this.running,
    required this.isStopping,
    required this.onInstall,
    required this.onPause,
    required this.onCancel,
    required this.onRemove,
  });

  final ModelInstallState state;

  /// The original voice is on, so this is the converter the pipeline uses.
  final bool inUse;
  final bool running;
  final bool Function(String id) isStopping;
  final void Function(ModelInstallState state) onInstall;
  final void Function(ModelInstallState state) onPause;
  final void Function(ModelInstallState state) onCancel;
  final void Function(ModelInstallState state) onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final model = state.model;
    final progress = state.progress;
    return ModelTile(
      title: 'OpenVoice ${model.version ?? ''}'.trim(),
      parts: [
        ModelTilePart(
          label: l10n.modelPartConverter,
          bytes: model.downloadBytes,
          installed: state.installed,
        ),
      ],
      progress: progress,
      paused: state.paused,
      installed: state.installed,
      inUse: inUse && state.installed && progress == null,
      marked: inUse,
      tooltip: [
        modelTitle(l10n, model),
        modelDescription(l10n, model),
        if (progress != null)
          _progressLine(l10n, progress, model.downloadBytes)
        else
          inUse ? l10n.converterHintInUse : l10n.converterHintIdle,
      ].join('\n'),
      onTap: null,
      actions: modelActions(
        l10n: l10n,
        parts: [state],
        isStopping: isStopping,
        locked: running && inUse,
        onInstall: onInstall,
        onPause: onPause,
        onCancel: onCancel,
        onRemove: () async {
          final confirmed = await confirmModelRemoval(
            context,
            title: l10n.modelRemoveTitle,
            message: l10n.modelRemoveMessage(
              modelTitle(l10n, model),
              formatPackageSize(model.downloadBytes),
            ),
          );
          if (confirmed) onRemove(state);
        },
      ),
    );
  }
}

String _progressLine(AppLocalizations l10n, double progress, int total) =>
    l10n.whisperDownloadProgress(
      (progress * 100).round(),
      formatPackageSize((total * progress).round()),
      formatPackageSize(total),
    );
