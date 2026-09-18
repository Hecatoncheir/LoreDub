// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/glossary.dart';
import 'package:lore_dub/src/domain/glossary_view.dart';

void main() {
  const fire = GlossaryEntry(
    kind: GlossaryKind.phrase,
    source: 'Fire in the hole!',
    reading: 'Ложись!',
  );
  const reloading = GlossaryEntry(
    kind: GlossaryKind.phrase,
    source: 'Reloading!',
    reading: '',
    silent: true,
  );
  const megaton = GlossaryEntry(kind: GlossaryKind.name, source: 'Megaton', reading: 'Мегатон');
  final glossary = Glossary(
    entries: const [fire, reloading, megaton],
    packs: [
      GlossaryPack(id: 'p1', name: 'Fallout', entryKeys: [megaton.packKey, fire.packKey]),
    ],
  );

  test('lists only what no pack holds to begin with', () {
    final view = GlossaryView(glossary, const GlossaryFilter());

    expect(view.listed(GlossaryKind.phrase), [reloading]);
    expect(view.listed(GlossaryKind.name), isEmpty);
    expect(view.held(GlossaryKind.name), 1, reason: 'narrowed to nothing, not empty');
  });

  test('shows the glossary whole with the preset off', () {
    final view = GlossaryView(glossary, const GlossaryFilter(looseOnly: false));

    expect(view.listed(GlossaryKind.phrase), [fire, reloading]);
  });

  test('narrows to the silenced lines', () {
    final view = GlossaryView(glossary, const GlossaryFilter(looseOnly: false, silentOnly: true));

    expect(view.listed(GlossaryKind.phrase), [reloading]);
  });

  test('finds an entry by either half', () {
    const byReading = GlossaryFilter(looking: 'ложись', looseOnly: false);
    const bySource = GlossaryFilter(looking: 'mega', looseOnly: false);

    expect(GlossaryView(glossary, byReading).listed(GlossaryKind.phrase), [fire]);
    expect(GlossaryView(glossary, bySource).listed(GlossaryKind.name), [megaton]);
  });

  test('narrows a pack by the search alone, in the order the lists keep', () {
    final pack = glossary.packs.single;

    expect(GlossaryView(glossary, const GlossaryFilter()).membersOf(pack), [fire, megaton]);
    expect(
      GlossaryView(glossary, const GlossaryFilter(looking: 'mega')).membersOf(pack),
      [megaton],
    );
  });
}
