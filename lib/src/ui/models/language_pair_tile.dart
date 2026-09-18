// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/language_pair.dart';
import '../../domain/model_package.dart';
import '../compute_names.dart';
import '../language_names.dart';
import '../model_names.dart';
import 'model_removal.dart';
import 'model_tile_part.dart';
import 'model_action.dart';
import 'model_tile.dart';
import 'download_progress_line.dart';

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

  /// What the tile's tooltip ends on: how far a download has got, or what
  /// a press does.
  String _hint(AppLocalizations l10n) {
    if (pair.progress case final progress?) {
      return downloadProgressLine(l10n, progress, pair.downloadBytes);
    }
    if (selected) return l10n.languageHintSelected;
    return onSelect == null ? l10n.languageHintLocked : l10n.languageHintSelect;
  }

  /// Both halves go together, and only once the player has said so.
  Future<void> _remove(BuildContext context, AppLocalizations l10n, String name) async {
    final confirmed = await confirmModelRemoval(
      context,
      title: l10n.languageRemoveTitle,
      message: l10n.languageRemoveMessage(name, formatPackageSize(l10n, pair.downloadBytes)),
    );
    if (!confirmed) return;
    for (final part in pair.parts) {
      if (part.installed) onRemove(part);
    }
  }

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
        _hint(l10n),
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
        onRemove: () => _remove(context, l10n, name),
      ),
    );
  }
}
