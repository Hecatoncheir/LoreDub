// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../../../l10n/app_localizations.dart';
import '../../../domain/pipeline_graph.dart';

/// Why a link came to nothing, in the interface language.
String describeConnectionRefusal(AppLocalizations l10n, ConnectionRefusal reason) =>
    switch (reason) {
      ConnectionRefusal.signal => l10n.pipelineRefusalSignal,
      ConnectionRefusal.direction => l10n.pipelineRefusalDirection,
      ConnectionRefusal.sameNode => l10n.pipelineRefusalSameNode,
      ConnectionRefusal.unsupported => l10n.pipelineRefusalUnsupported,
      ConnectionRefusal.loop => l10n.pipelineRefusalLoop,
      ConnectionRefusal.locked => l10n.pipelineRefusalLocked,
      ConnectionRefusal.translatorMissing => l10n.pipelineRefusalTranslatorMissing,
      ConnectionRefusal.outOfLine => l10n.pipelineRefusalOutOfLine,
      ConnectionRefusal.converterMissing => l10n.pipelineRefusalConverterMissing,
    };
