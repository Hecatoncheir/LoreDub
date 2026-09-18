// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/app_release.dart';
import '../../../l10n/app_localizations.dart';
import '../theme.dart';
import '../dashboard/cubits/shell_cubit.dart';
import 'footer_insets.dart';
import 'update_row.dart';

/// The version, and what is known about newer ones.
///
/// Tapping it checks again; while a check runs the spinner takes the place of
/// nothing else, so the row does not resize. Once a newer version is
/// published the version steps aside for [UpdateRow].
class VersionButton extends StatelessWidget {
  const VersionButton({super.key});

  String _tooltip(AppLocalizations l10n, UpdateState updates) => switch (updates.status) {
    UpdateStatus.checking => l10n.updateChecking,
    UpdateStatus.current => l10n.updateUpToDate,
    UpdateStatus.failed => l10n.updateFailed,
    _ => l10n.updateCheckAgain,
  };

  @override
  Widget build(BuildContext context) => BlocBuilder<ShellCubit, ShellState>(
    builder: (context, shell) => _build(context, shell.updates),
  );

  Widget _build(BuildContext context, UpdateState updates) {
    final l10n = AppLocalizations.of(context);
    final version = updates.currentVersion;
    if (updates.hasUpdate) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(FooterInsets.outer, 0, 8, 8),
        child: UpdateRow(updates: updates),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(FooterInsets.outer, 0, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: _tooltip(l10n, updates),
              child: TextButton(
                onPressed: updates.checking
                    ? null
                    : () => context.read<ShellCubit>().checkForUpdates(),
                style: TextButton.styleFrom(
                  foregroundColor: LoreDubPalette.mutedInk,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: FooterInsets.button),
                  minimumSize: const Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontFamily: LoreDubFonts.mono,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: FooterInsets.iconSize,
                      height: FooterInsets.iconSize,
                      child: updates.checking
                          ? const CircularProgressIndicator(strokeWidth: 2)
                          : Icon(
                              updates.status == UpdateStatus.failed
                                  ? Icons.cloud_off_rounded
                                  : Icons.verified_outlined,
                              size: FooterInsets.iconSize,
                              color: LoreDubPalette.mutedInk,
                            ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        version.isEmpty ? '—' : l10n.updateCurrent(version),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
