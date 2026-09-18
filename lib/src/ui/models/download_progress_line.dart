// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../../l10n/app_localizations.dart';
import '../compute_names.dart';

/// How far a download has got, for a tile's tooltip: the share and the
/// megabytes of the whole.
String downloadProgressLine(AppLocalizations l10n, double progress, int total) =>
    l10n.whisperDownloadProgress(
      (progress * 100).round(),
      formatPackageSize(l10n, (total * progress).round()),
      formatPackageSize(l10n, total),
    );
