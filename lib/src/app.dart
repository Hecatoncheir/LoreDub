// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';
import 'composition.dart';
import 'domain/app_settings.dart';
import 'ui/common/file_dialogs.dart';
import 'ui/settings/bloc/settings_bloc.dart';
import 'ui/shell/dashboard_providers.dart';
import 'ui/shell/dashboard_scaffold.dart';
import 'ui/graph/node_faces.dart';
import 'ui/theme.dart';
import 'ui/app/interface_scale.dart';

class LoreDubBootstrap extends StatefulWidget {
  const LoreDubBootstrap({super.key});

  @override
  State<LoreDubBootstrap> createState() => _LoreDubBootstrapState();
}

class _LoreDubBootstrapState extends State<LoreDubBootstrap> {
  /// What the application is made of, below its screens.
  final app = AppComposition();

  /// The repositories are this state's, not any one screen's. The screens'
  /// providers sit below and have been told to close by the time this
  /// runs, so the engine they share is let go of last.
  @override
  void dispose() {
    app.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider.value(value: app.sessions),
      RepositoryProvider.value(value: app.system),
      RepositoryProvider.value(value: app.voiceBank),
      RepositoryProvider.value(value: app.schemes),
      RepositoryProvider.value(value: app.glossary),
      RepositoryProvider.value(value: app.models),
      RepositoryProvider.value(value: app.runtimes),
      RepositoryProvider.value(value: app.settings),
      RepositoryProvider.value(value: app.updates),
      RepositoryProvider.value(value: app.installed),
      RepositoryProvider.value(value: app.cast),
      RepositoryProvider.value(value: app.sources),
      RepositoryProvider.value(value: app.coordinator),
      RepositoryProvider.value(value: const FileDialogs()),
    ],
    // Above the application rather than under it, so a dialog pushed on the
    // navigator reads the same screens the page it came from does.
    child: DashboardProviders(
      child: BlocBuilder<SettingsBloc, SettingsState>(
        // Only the settings are watched here, so switching the interface
        // language takes effect without a restart and nothing else rebuilds the
        // application above the dashboard.
        buildWhen: (previous, current) =>
            previous.settings.interfaceLanguage != current.settings.interfaceLanguage ||
            previous.settings.chosenScale != current.settings.chosenScale ||
            previous.settings.interfaceTheme != current.settings.interfaceTheme,
        builder: (context, state) => MaterialApp(
          title: 'LoreDub',
          debugShowCheckedModeBanner: false,
          // The faces of the canvas ride on the theme rather than in the
          // theme layer: what a node looks like is the graph screen's own.
          theme: AppTheme.light.withNodeFaces(),
          darkTheme: AppTheme.dark.withNodeFaces(NodeFaces.from(LoreDubColors.dark)),
          themeMode: switch (state.settings.interfaceTheme) {
            InterfaceTheme.system => ThemeMode.system,
            InterfaceTheme.light => ThemeMode.light,
            InterfaceTheme.dark => ThemeMode.dark,
          },
          locale: Locale(state.settings.interfaceLanguage),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: InterfaceScale(
            scale: state.settings.chosenScale,
            child: const DashboardScaffold(),
          ),
        ),
      ),
    ),
  );
}
