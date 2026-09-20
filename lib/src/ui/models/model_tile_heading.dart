// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../compute_names.dart';
import '../theme.dart';
import 'model_tile_part.dart';

/// The top of a model tile: its name with a cloud saying whether it is on
/// disk, and under it a line for each part with its size, ticked once it
/// arrived.
class ModelTileHeading extends StatelessWidget {
  const ModelTileHeading({
    super.key,
    required this.title,
    required this.parts,
    required this.downloading,
    required this.installed,
    required this.inUse,
    required this.ink,
  });

  final String title;
  final List<ModelTilePart> parts;

  /// A download is drawn by the dial below, so the cloud steps aside.
  final bool downloading;
  final bool installed;
  final bool inUse;
  final Color ink;

  Color _tick(ModelTilePart part, LoreDubColors colors) {
    if (!part.installed) return ink.withValues(alpha: 0.6);
    return inUse ? colors.accent : colors.success;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detail = TextStyle(fontFamily: LoreDubFonts.mono, fontSize: 11, color: ink);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              // A long name such as "CUDA · translation" shrinks to fit
              // rather than losing its end.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: LoreDubFonts.display,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ),
            ),
            if (!downloading)
              Icon(
                installed ? Icons.cloud_done_outlined : Icons.cloud_download_outlined,
                size: 22,
                color: inUse || !installed ? context.colors.accent : context.colors.ink,
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
                  color: _tick(part, context.colors),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(part.label, style: detail)),
                Text(formatPackageSize(l10n, part.bytes), style: detail),
              ],
            ),
          ),
      ],
    );
  }
}
