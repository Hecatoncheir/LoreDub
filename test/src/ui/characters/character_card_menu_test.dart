// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/l10n/app_localizations.dart';
import 'package:lore_dub/src/domain/character.dart';
import 'package:lore_dub/src/ui/characters/character_card_menu.dart';

void main() {
  testWidgets('files a card in a pack without dragging it', (tester) async {
    final filed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CharacterCardMenu(
            characterId: 'guard',
            onExport: null,
            onDelete: () {},
            packs: const [
              CharacterPack(id: 'town', name: 'Town', characterIds: ['guard']),
              CharacterPack(id: 'vault', name: 'Vault'),
            ],
            onFileInPack: filed.add,
          ),
        ),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byTooltip(l10n.charactersCardMenu));
    await tester.pumpAndSettle();
    // The pack already holding the card is named and cannot be chosen.
    await tester.tap(find.text(l10n.packsFileInto('Town')));
    await tester.pumpAndSettle();
    expect(filed, isEmpty);

    await tester.tap(find.text(l10n.packsFileInto('Vault')));
    await tester.pumpAndSettle();
    expect(filed, ['vault']);
  });
}
