// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../../l10n/app_localizations.dart';
import 'bloc/navigation_cubit.dart';

/// The strap over the title: where the section stands in the order the work
/// is done in, and the name of its area.
///
/// Numbered off [DashboardSection] rather than by hand, so a screen put
/// between two others renumbers the rest by itself.
extension SectionMark on DashboardSection {
  /// [liveView] and [screenView] name the half of Эфир and of Экран that is
  /// up: a scheme is the path of the signal, whichever session it draws.
  String mark(
    AppLocalizations l10n, {
    LiveView liveView = LiveView.dubbing,
    ScreenView screenView = ScreenView.reading,
  }) {
    final scheme = switch (this) {
      DashboardSection.live => liveView == LiveView.scheme,
      DashboardSection.snapshot => screenView == ScreenView.scheme,
      _ => false,
    };
    if (scheme) return '$_number  /  ${l10n.headerPipeline}';
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

  /// The heading of the section. Эфир and Экран are headed by the switch
  /// between their two halves instead, which names both.
  String title(AppLocalizations l10n) => switch (this) {
    DashboardSection.live => l10n.titleLive,
    DashboardSection.snapshot => l10n.titleSnapshot,
    DashboardSection.characters => l10n.titleCharacters,
    DashboardSection.glossary => l10n.titleGlossary,
    DashboardSection.models => l10n.titleModels,
    DashboardSection.settings => l10n.titleSettings,
  };

  String get _number => (index + 1).toString().padLeft(2, '0');
}
