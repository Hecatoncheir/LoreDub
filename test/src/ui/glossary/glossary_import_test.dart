// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/l10n/app_localizations.dart';
import 'package:lore_dub/src/ui/common/file_dialogs.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/glossary_bloc.dart';
import 'package:lore_dub/src/ui/glossary/glossary_panel.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/mock_blocs.dart';

void main() {
  setUpAll(registerEventFallbacks);

  Future<void> pump(WidgetTester tester, GlossaryBloc glossary, FileDialogs dialogs) =>
      tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RepositoryProvider<FileDialogs>.value(
            value: dialogs,
            child: BlocProvider.value(
              value: glossary,
              child: const Scaffold(body: GlossaryPanel()),
            ),
          ),
        ),
      );

  testWidgets('reads the files the player chose through the file seam', (tester) async {
    final glossary = glossaryShowing(const GlossaryState(loaded: true));
    await pump(tester, glossary, _Dialogs(['C:/games/vault.json']));

    await tester.tap(find.byKey(const ValueKey('glossary-import')));
    await tester.pumpAndSettle();

    verify(() => glossary.add(const GlossaryFilesImported(['C:/games/vault.json']))).called(1);
  });

  testWidgets('sends nothing when the dialog is closed with nothing chosen', (tester) async {
    final glossary = glossaryShowing(const GlossaryState(loaded: true));
    await pump(tester, glossary, _Dialogs(const []));

    await tester.tap(find.byKey(const ValueKey('glossary-import')));
    await tester.pumpAndSettle();

    verifyNever(() => glossary.add(any()));
  });

  testWidgets('says what an import held, once, when the bloc has read it', (tester) async {
    const read = GlossaryImport(number: 1, entries: 2, packs: 1);
    final glossary = glossaryShowing(
      const GlossaryState(loaded: true),
      then: Stream.value(const GlossaryState(loaded: true, lastImport: read)),
    );
    await pump(tester, glossary, _Dialogs(const []));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.glossaryImported(2, 1)), findsOneWidget);
  });
}

class _Dialogs extends FileDialogs {
  _Dialogs(this.chosen);

  final List<String> chosen;

  @override
  Future<List<String>> openJson() async => chosen;
}
