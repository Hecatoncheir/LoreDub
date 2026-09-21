// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../../l10n/app_localizations.dart';
import '../dashboard/cubits/navigation_cubit.dart';

/// The strap over the title: where the section stands in the order the work
/// is done in, and the name of its area.
///
/// Numbered off [DashboardSection] rather than by hand, so a screen put
/// between two others renumbers the rest by itself.
extension SectionMark on DashboardSection {
  /// [liveView] names the half of Эфир that is up, the scheme having been
  /// a screen of its own once.
  String mark(AppLocalizations l10n, {LiveView liveView = LiveView.dubbing}) {
    if (this == DashboardSection.live && liveView == LiveView.scheme) {
      return '$_number  /  ${l10n.headerPipeline}';
    }
    final area = switch (this) {
      DashboardSection.live => l10n.headerLive,
      DashboardSection.snapshot => l10n.headerScreen,
      DashboardSection.characters => l10n.headerCharacters,
      DashboardSection.glossary => l10n.headerGlossary,
      DashboardSection.models => l10n.headerModels,
      DashboardSection.settings => l10n.headerSettings,
    };
    return '$_number  /  $area';
  }

  String get _number => (index + 1).toString().padLeft(2, '0');
}
