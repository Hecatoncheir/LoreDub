// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/l10n/app_localizations.dart';
import 'package:lore_dub/src/domain/glossary.dart';
import 'package:lore_dub/src/ui/glossary/glossary_entry_handle.dart';

void main() {
  testWidgets('a click on the handle files the entry in a pack', (tester) async {
    const entry = GlossaryEntry(kind: GlossaryKind.name, source: 'Vault', reading: 'Убежище');
    final filed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: GlossaryEntryHandle(
            entry: entry,
            packs: [
              GlossaryPack(id: 'held', name: 'Held', entryKeys: [entry.packKey]),
              const GlossaryPack(id: 'fallout', name: 'Fallout'),
            ],
            onFileInPack: filed.add,
          ),
        ),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byType(GlossaryEntryHandle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.packsFileInto('Held')));
    await tester.pumpAndSettle();
    expect(filed, isEmpty);

    await tester.tap(find.byType(GlossaryEntryHandle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.packsFileInto('Fallout')));
    await tester.pumpAndSettle();
    expect(filed, ['fallout']);
  });
}
