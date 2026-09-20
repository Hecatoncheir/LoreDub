// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/l10n/app_localizations.dart';
import 'package:lore_dub/src/data/repositories/settings_repository.dart';
import 'package:lore_dub/src/data/repositories/app_repository.dart';
import 'package:lore_dub/src/data/services/native_engine_service.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/domain/glossary.dart';
import 'package:lore_dub/src/ui/common/file_dialogs.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/glossary_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/shell_cubit.dart';
import 'package:lore_dub/src/ui/glossary/glossary_panel.dart';

void main() {
  testWidgets('says what an imported glossary held, read through the file seam', (tester) async {
    final repository = _GlossaryRepository();
    final glossary = GlossaryCubit(repository, _Failures())
      ..seed(const GlossaryState(loaded: true));
    final dialogs = _Dialogs(['C:/games/vault.json']);

    await tester.pumpWidget(
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
    await tester.tap(find.byKey(const ValueKey('glossary-import')));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(repository.read, ['C:/games/vault.json']);
    expect(find.text(l10n.glossaryImported(2, 1)), findsOneWidget);
    expect(glossary.state.glossary.entries, hasLength(2));
    await glossary.close();
  });
}

class _Dialogs extends FileDialogs {
  _Dialogs(this.chosen);

  final List<String> chosen;

  @override
  Future<List<String>> openJson() async => chosen;
}

class _Failures implements FailureSink {
  @override
  void report(Object? error) => fail('reported $error');
}

class _GlossaryRepository extends AppRepository {
  _GlossaryRepository() : super(NativeEngineService(), SettingsRepository(SettingsService()));

  List<String> read = const [];

  @override
  Future<Glossary> readGlossaryFiles(List<String> sources) async {
    read = sources;
    return const Glossary(
      entries: [
        GlossaryEntry(kind: GlossaryKind.name, source: 'Vault', reading: 'Убежище'),
        GlossaryEntry(kind: GlossaryKind.phrase, source: 'War never changes.', reading: 'Война'),
      ],
      packs: [GlossaryPack(id: 'p', name: 'Fallout')],
    );
  }

  @override
  Future<void> saveGlossary(Glossary glossary) async {}
}
