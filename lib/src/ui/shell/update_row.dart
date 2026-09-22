// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/app_release.dart';
import '../../../l10n/app_localizations.dart';
import '../app_icons.dart';
import '../theme.dart';
import 'bloc/update_bloc.dart';
import 'footer_insets.dart';

/// A newer version, in three steps on the spot the version held: where the
/// update goes ("v0.8.0 → v0.9.0"), a bar while its setup downloads, and
/// "Updated" with the restart that runs the setup.
///
/// A running application cannot overwrite its own files, so the setup itself
/// runs in the few seconds between closing and opening again; the bar is the
/// download, which is nearly all of the wait.
class UpdateRow extends StatelessWidget {
  const UpdateRow({super.key, required this.updates});

  final UpdateState updates;

  static const _label = TextStyle(
    fontFamily: LoreDubFonts.mono,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final release = updates.release!;
    if (updates.readyToRestart) {
      return Row(
        children: [
          const SizedBox(width: FooterInsets.button),
          // The word never breaks: beside the restart the sidebar is narrow,
          // so it shrinks a little rather than wrapping mid-word.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.updateInstalled,
                maxLines: 1,
                style: _label.copyWith(color: context.colors.ink),
              ),
            ),
          ),
          Tooltip(
            message: l10n.updateRestartHint,
            child: TextButton.icon(
              key: const ValueKey('updateRestart'),
              onPressed: () => context.read<UpdateBloc>().add(const UpdateRestartAsked()),
              icon: LoreDubIcons.directorySync(color: context.colors.accent, size: 16),
              label: Text(l10n.updateRestart),
              style: TextButton.styleFrom(
                foregroundColor: context.colors.accentStrong,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: _label.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      );
    }
    if (updates.installProgress case final progress?) {
      return Tooltip(
        message: l10n.updateDownloading,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: FooterInsets.button, vertical: 11),
          child: Row(
            children: [
              Expanded(child: LinearProgressIndicator(value: progress, minHeight: 6)),
              const SizedBox(width: 8),
              Text('${(progress * 100).round()}%', style: _label),
            ],
          ),
        ),
      );
    }
    return Tooltip(
      // A build run from its folder cannot be replaced by the setup, so it
      // is sent to the page instead, and says so.
      message: updates.installable
          ? l10n.updateInstallHint
          : l10n.updateOpenRelease(release.version),
      child: TextButton(
        key: const ValueKey('updateAvailable'),
        onPressed: () => context.read<UpdateBloc>().add(const UpdateInstallAsked()),
        style: TextButton.styleFrom(
          foregroundColor: context.colors.ink,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: FooterInsets.button, vertical: 6),
          minimumSize: const Size(0, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: _label,
        ),
        child: Row(
          children: [
            Flexible(
              child: Text(
                l10n.updateFromTo(updates.currentVersion, release.version),
                maxLines: 2,
              ),
            ),
            const SizedBox(width: 6),
            LoreDubIcons.deployedCodeUpdate(color: context.colors.accent, size: 18),
          ],
        ),
      ),
    );
  }
}
