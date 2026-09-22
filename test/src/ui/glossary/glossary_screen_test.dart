// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// The glossary screen: the three lists, the packs and the search.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/l10n/app_localizations.dart';
import 'package:lore_dub/src/domain/glossary.dart';
import 'package:lore_dub/src/ui/glossary/bloc/glossary_bloc.dart';
import 'package:lore_dub/src/ui/shell/bloc/navigation_cubit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/dashboard_harness.dart';
import '../../../support/mock_blocs.dart';

void main() {
  // What `captureAny` stands in with before anything is captured.
  setUpAll(registerEventFallbacks);

  // What the entry is filed under is shown rather than edited, but a phrase
  // written down here is wanted elsewhere, so it can be selected and copied.
  testWidgets('lets a glossary phrase be selected', (tester) async {
    final glossary = glossaryShowing(
      const GlossaryState(
        loaded: true,
        glossary: Glossary(
          entries: [
            GlossaryEntry(
              kind: GlossaryKind.phrase,
              source: 'Fire in the hole!',
              reading: 'Ложись!',
            ),
          ],
        ),
      ),
    );
    final cubits = stage(buildCubits(glossary: glossary), section: DashboardSection.glossary);
    await pumpDashboard(tester, cubits, const Size(1280, 1000));

    expect(
      find.descendant(
        of: find.byType(SelectableText),
        matching: find.text('Fire in the hole!'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('makes a glossary pack and fills it from the lists', (tester) async {
    final glossary = glossaryShowing(
      const GlossaryState(
        loaded: true,
        glossary: Glossary(
          entries: [
            GlossaryEntry(
              kind: GlossaryKind.phrase,
              source: 'Fire in the hole!',
              reading: 'Ложись!',
            ),
          ],
        ),
      ),
    );
    final cubits = stage(buildCubits(glossary: glossary), section: DashboardSection.glossary);
    await pumpDashboard(tester, cubits, const Size(1400, 1000));

    final add = find.byKey(const ValueKey('glossary-pack-add'));
    await tester.scrollUntilVisible(add, 300, scrollable: glossaryScroller());
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();

    // What a new pack holds, and that it narrows nothing, is the bloc's:
    // `glossary_bloc_test.dart`.
    verify(() => glossary.add(const GlossaryPackAdded('Новый пакет'))).called(1);
  });

  // The whole point of the switch: with a pack on, the dubbing is checked
  // against that pack and nothing else.
  testWidgets('narrows the glossary to the pack that is switched on', (tester) async {
    const fire = GlossaryEntry(
      kind: GlossaryKind.phrase,
      source: 'Fire in the hole!',
      reading: 'Ложись!',
    );
    const megaton = GlossaryEntry(
      kind: GlossaryKind.name,
      source: 'Megaton',
      reading: 'Мегатон',
    );
    final glossary = glossaryShowing(
      GlossaryState(
        loaded: true,
        glossary: Glossary(
          entries: const [fire, megaton],
          packs: [
            GlossaryPack(id: 'p1', name: 'Fallout', entryKeys: [megaton.packKey]),
          ],
        ),
      ),
    );
    final cubits = stage(buildCubits(glossary: glossary), section: DashboardSection.glossary);
    await pumpDashboard(tester, cubits, const Size(1400, 1000));

    final toggle = find.byKey(const ValueKey('glossary-pack-active-p1'));
    await tester.scrollUntilVisible(toggle, 300, scrollable: glossaryScroller());
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    verify(() => glossary.add(const GlossaryPackSwitched('p1', active: true))).called(1);
  });

  testWidgets('asks before a glossary pack is thrown away, and keeps its entries', (tester) async {
    const megaton = GlossaryEntry(
      kind: GlossaryKind.name,
      source: 'Megaton',
      reading: 'Мегатон',
    );
    final glossary = glossaryShowing(
      GlossaryState(
        loaded: true,
        glossary: Glossary(
          entries: const [megaton],
          packs: [
            GlossaryPack(id: 'p1', name: 'Fallout', entryKeys: [megaton.packKey]),
          ],
        ),
      ),
    );
    final cubits = stage(buildCubits(glossary: glossary), section: DashboardSection.glossary);
    await pumpDashboard(tester, cubits, const Size(1400, 1000));
    final l10n = await AppLocalizations.delegate.load(const Locale('ru'));

    final delete = find.byKey(const ValueKey('glossary-pack-delete-p1'));
    await tester.scrollUntilVisible(delete, 300, scrollable: glossaryScroller());
    await tester.pumpAndSettle();
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(find.text(l10n.glossaryPackDeleteMessage('Fallout')), findsOneWidget);
    await tester.tap(find.text(l10n.charactersDeleteCancel));
    await tester.pumpAndSettle();
    verifyNever(() => glossary.add(const GlossaryPackRemoved('p1')));

    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.charactersDeleteConfirm));
    await tester.pumpAndSettle();
    // The entries staying is the bloc's: `glossary_bloc_test.dart`.
    verify(() => glossary.add(const GlossaryPackRemoved('p1'))).called(1);
  });

  // A pack is chosen while looking at what goes into it, so it stands beside
  // the lists where the window is wide enough to hold both.
  testWidgets('stands the packs beside the lists and under them when narrow', (tester) async {
    Future<double> widthAt(WidgetTester tester, Size size) async {
      final glossary = glossaryShowing(const GlossaryState(loaded: true));
      final cubits = stage(buildCubits(glossary: glossary), section: DashboardSection.glossary);
      await pumpDashboard(tester, cubits, size);
      final packs = find.byKey(const ValueKey('glossaryPacks'));
      await tester.scrollUntilVisible(packs, 300, scrollable: glossaryScroller());
      await tester.pumpAndSettle();
      return tester.getSize(packs).width;
    }

    expect(await widthAt(tester, const Size(1400, 1000)), lessThan(400));
    expect(await widthAt(tester, const Size(1000, 1000)), greaterThan(600));
  });

  // A shout the game repeats every few seconds is worth hearing once.
  testWidgets('passes a phrase over from the glossary, and only a phrase', (tester) async {
    const fire = GlossaryEntry(
      kind: GlossaryKind.phrase,
      source: 'Reloading!',
      reading: 'Перезарядка!',
    );
    const megaton = GlossaryEntry(
      kind: GlossaryKind.name,
      source: 'Megaton',
      reading: 'Мегатон',
    );
    final glossary = glossaryShowing(
      const GlossaryState(loaded: true, glossary: Glossary(entries: [fire, megaton])),
    );
    final cubits = stage(buildCubits(glossary: glossary), section: DashboardSection.glossary);
    await pumpDashboard(tester, cubits, const Size(1400, 1000));

    expect(find.byKey(ValueKey('glossary-silence-${megaton.packKey}')), findsNothing);

    final silence = find.byKey(ValueKey('glossary-silence-${fire.packKey}'));
    await tester.scrollUntilVisible(silence, 300, scrollable: glossaryScroller());
    await tester.pumpAndSettle();
    await tester.tap(silence);
    await tester.pumpAndSettle();

    final written =
        verify(() => glossary.add(captureAny())).captured.single as GlossaryEntryWritten;
    expect(written.entry.source, 'Reloading!');
    expect(written.entry.silent, isTrue);
  });

  // A glossary grows to hundreds of lines and the one being looked for is
  // remembered by a word of it, not by where it stands.
  testWidgets('narrows the lists to what the search asks for', (tester) async {
    final glossary = glossaryShowing(
      const GlossaryState(
        loaded: true,
        glossary: Glossary(
          entries: [
            GlossaryEntry(
              kind: GlossaryKind.phrase,
              source: 'Fire in the hole!',
              reading: 'Ложись!',
            ),
            GlossaryEntry(
              kind: GlossaryKind.phrase,
              source: 'Reloading!',
              reading: 'Перезарядка!',
            ),
          ],
        ),
      ),
    );
    final cubits = stage(buildCubits(glossary: glossary), section: DashboardSection.glossary);
    await pumpDashboard(tester, cubits, const Size(1400, 1000));

    expect(find.text('Fire in the hole!'), findsOneWidget);
    expect(find.text('Reloading!'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('glossary-search')), 'reload');
    await tester.pumpAndSettle();

    expect(find.text('Fire in the hole!'), findsNothing);
    expect(find.text('Reloading!'), findsOneWidget);

    // The Russian half answers too: the player may remember what they wrote
    // rather than what they heard.
    await tester.enterText(find.byKey(const ValueKey('glossary-search')), 'ложись');
    await tester.pumpAndSettle();

    expect(find.text('Fire in the hole!'), findsOneWidget);
    expect(find.text('Reloading!'), findsNothing);
  });

  // All three lists, not the first of them: a name is remembered by a piece
  // of it as often as a phrase is, and a list the search passed by would go
  // on showing everything beside two that had been narrowed.
  testWidgets('narrows the names and the words to the search as well', (tester) async {
    const fire = GlossaryEntry(
      kind: GlossaryKind.phrase,
      source: 'Fire in the hole!',
      reading: 'Ложись!',
    );
    const megaton = GlossaryEntry(kind: GlossaryKind.name, source: 'Megaton', reading: 'Мегатон');
    const rapture = GlossaryEntry(kind: GlossaryKind.name, source: 'Rapture', reading: 'Рапчер');
    const vault = GlossaryEntry(kind: GlossaryKind.word, source: 'Хранилище', reading: 'Убежище');
    const whiterun = GlossaryEntry(kind: GlossaryKind.word, source: 'Белгород', reading: 'Вайтран');
    final glossary = glossaryShowing(
      const GlossaryState(
        loaded: true,
        glossary: Glossary(entries: [fire, megaton, rapture, vault, whiterun]),
      ),
    );
    final cubits = stage(buildCubits(glossary: glossary), section: DashboardSection.glossary);
    await pumpDashboard(tester, cubits, const Size(1400, 1000));

    Finder row(GlossaryEntry entry) => find.byKey(ValueKey('${entry.kind.name}:${entry.key}'));

    for (final entry in [fire, megaton, rapture, vault, whiterun]) {
      expect(row(entry), findsOneWidget);
    }

    await tester.enterText(find.byKey(const ValueKey('glossary-search')), 'mega');
    await tester.pumpAndSettle();

    expect(row(megaton), findsOneWidget);
    for (final entry in [fire, rapture, vault, whiterun]) {
      expect(row(entry), findsNothing);
    }

    // What was written answers for a word as it does for a phrase.
    await tester.enterText(find.byKey(const ValueKey('glossary-search')), 'убежищ');
    await tester.pumpAndSettle();

    expect(row(vault), findsOneWidget);
    for (final entry in [fire, megaton, rapture, whiterun]) {
      expect(row(entry), findsNothing);
    }
  });

  // The search narrows a pack as well, so a line can be found and dragged in
  // one motion -- and the count still says what the pack holds.
  testWidgets('narrows a pack to the search without changing what it holds', (tester) async {
    const fire = GlossaryEntry(
      kind: GlossaryKind.phrase,
      source: 'Fire in the hole!',
      reading: 'Ложись!',
    );
    const reloading = GlossaryEntry(
      kind: GlossaryKind.phrase,
      source: 'Reloading!',
      reading: 'Перезарядка!',
    );
    final glossary = glossaryShowing(
      GlossaryState(
        loaded: true,
        glossary: Glossary(
          entries: const [fire, reloading],
          packs: [
            GlossaryPack(
              id: 'p1',
              name: 'Shooters',
              entryKeys: [fire.packKey, reloading.packKey],
            ),
          ],
        ),
      ),
    );
    final cubits = stage(buildCubits(glossary: glossary), section: DashboardSection.glossary);
    await pumpDashboard(tester, cubits, const Size(1400, 1000));

    final pack = find.byKey(const ValueKey('glossary-pack-p1'));
    final search = find.byKey(const ValueKey('glossary-search'));
    await tester.scrollUntilVisible(pack, 300, scrollable: glossaryScroller());
    await tester.pumpAndSettle();
    expect(find.descendant(of: pack, matching: find.text('Fire in the hole!')), findsOneWidget);
    expect(find.descendant(of: pack, matching: find.text('Reloading!')), findsOneWidget);

    // The field stands at the head of the page, which the scroll left above.
    await tester.scrollUntilVisible(search, -300, scrollable: glossaryScroller());
    await tester.pumpAndSettle();
    await tester.enterText(search, 'reload');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(pack, 300, scrollable: glossaryScroller());
    await tester.pumpAndSettle();

    expect(find.descendant(of: pack, matching: find.text('Fire in the hole!')), findsNothing);
    expect(find.descendant(of: pack, matching: find.text('Reloading!')), findsOneWidget);
    // Two, not one: the search hid a chip, it did not take an entry out.
    expect(find.descendant(of: pack, matching: find.textContaining('2')), findsWidgets);
  });

  // The packs that come with the application put a hundred entries into the
  // lists, and the handful the player wrote would be lost among them.
  testWidgets('opens on what no pack holds, and shows the rest when asked', (tester) async {
    const packed = GlossaryEntry(
      kind: GlossaryKind.phrase,
      source: 'Fire in the hole!',
      reading: 'Ложись!',
    );
    const mine = GlossaryEntry(
      kind: GlossaryKind.phrase,
      source: 'Open the gate.',
      reading: 'Открой ворота.',
    );
    const hushed = GlossaryEntry(
      kind: GlossaryKind.phrase,
      source: 'Reloading!',
      reading: '',
      silent: true,
    );
    final glossary = glossaryShowing(
      GlossaryState(
        loaded: true,
        glossary: Glossary(
          entries: const [packed, mine, hushed],
          packs: [
            GlossaryPack(id: 'p1', name: 'Shooters', entryKeys: [packed.packKey]),
          ],
        ),
      ),
    );
    final cubits = stage(buildCubits(glossary: glossary), section: DashboardSection.glossary);
    await pumpDashboard(tester, cubits, const Size(1400, 1000));

    // By the row's own key rather than by its text: the same line also shows
    // as a chip inside the pack, which the presets deliberately leave alone.
    Finder row(GlossaryEntry entry) => find.byKey(ValueKey('${entry.kind.name}:${entry.key}'));

    // The preset is on to begin with, so the packed line is not in the list.
    expect(row(mine), findsOneWidget);
    expect(row(hushed), findsOneWidget);
    expect(row(packed), findsNothing);

    await tester.tap(find.byKey(const ValueKey('glossary-preset-loose')));
    await tester.pumpAndSettle();
    expect(row(packed), findsOneWidget);

    // And the other preset leaves only the lines that are passed over.
    await tester.tap(find.byKey(const ValueKey('glossary-preset-silent')));
    await tester.pumpAndSettle();
    expect(row(hushed), findsOneWidget);
    expect(row(mine), findsNothing);
    expect(row(packed), findsNothing);
  });

  // A pack made for a game is mostly that game's names, so these are the two
  // lists the first preset has the most to say about.
  testWidgets('holds the names and the words to the presets as well', (tester) async {
    const packedName = GlossaryEntry(
      kind: GlossaryKind.name,
      source: 'Megaton',
      reading: 'Мегатон',
    );
    const looseName = GlossaryEntry(
      kind: GlossaryKind.name,
      source: 'Rapture',
      reading: 'Рапчер',
    );
    const packedWord = GlossaryEntry(
      kind: GlossaryKind.word,
      source: 'Хранилище',
      reading: 'Убежище',
    );
    const looseWord = GlossaryEntry(
      kind: GlossaryKind.word,
      source: 'Белгород',
      reading: 'Вайтран',
    );
    final glossary = glossaryShowing(
      GlossaryState(
        loaded: true,
        glossary: Glossary(
          entries: const [packedName, looseName, packedWord, looseWord],
          packs: [
            GlossaryPack(
              id: 'p1',
              name: 'Fallout',
              entryKeys: [packedName.packKey, packedWord.packKey],
            ),
          ],
        ),
      ),
    );
    final cubits = stage(buildCubits(glossary: glossary), section: DashboardSection.glossary);
    await pumpDashboard(tester, cubits, const Size(1400, 1000));

    Finder row(GlossaryEntry entry) => find.byKey(ValueKey('${entry.kind.name}:${entry.key}'));

    // "In no pack" is on to begin with, here as over the phrases.
    expect(row(looseName), findsOneWidget);
    expect(row(looseWord), findsOneWidget);
    expect(row(packedName), findsNothing);
    expect(row(packedWord), findsNothing);

    await tester.tap(find.byKey(const ValueKey('glossary-preset-loose')));
    await tester.pumpAndSettle();
    for (final entry in [packedName, looseName, packedWord, looseWord]) {
      expect(row(entry), findsOneWidget);
    }

    // Only a phrase can be passed over, so the other preset leaves nothing
    // of either list.
    await tester.tap(find.byKey(const ValueKey('glossary-preset-silent')));
    await tester.pumpAndSettle();
    for (final entry in [packedName, looseName, packedWord, looseWord]) {
      expect(row(entry), findsNothing);
    }
  });

  // "Nothing here yet" over a list holding twenty names reads as the names
  // being gone -- and one written under it, hidden the moment it is kept, as
  // not having been written at all.
  testWidgets('tells a list narrowed to nothing from one with nothing in it', (tester) async {
    const megaton = GlossaryEntry(kind: GlossaryKind.name, source: 'Megaton', reading: 'Мегатон');
    final glossary = glossaryShowing(
      const GlossaryState(loaded: true, glossary: Glossary(entries: [megaton])),
    );
    final cubits = stage(buildCubits(glossary: glossary), section: DashboardSection.glossary);
    await pumpDashboard(tester, cubits, const Size(1400, 1000));

    const empty = 'Пока пусто.';
    const hidden = 'Записи здесь есть, но их скрывает поиск или фильтр.';

    // No phrase and no word is written down, and the name is in view.
    expect(find.text(empty), findsNWidgets(2));
    expect(find.text(hidden), findsNothing);

    // Only a phrase can be passed over, so this preset hides the name, and
    // the two lists with nothing in them go on saying so.
    await tester.tap(find.byKey(const ValueKey('glossary-preset-silent')));
    await tester.pumpAndSettle();

    expect(find.text(empty), findsNWidgets(2));
    expect(find.text(hidden), findsOneWidget);
  });
}
