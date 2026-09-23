// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/repositories/glossary_repository.dart';
import 'package:lore_dub/src/data/repositories/settings_repository.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/domain/glossary.dart';
import 'package:lore_dub/src/domain/pipeline_graph.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fakes/memory_glossary.dart';
import '../../../support/memory_cast.dart';

/// The glossary two screens work on: the glossary screen writes it, the
/// canvas switches its packs and says what each of them may apply.
void main() {
  const fire = GlossaryEntry(
    kind: GlossaryKind.phrase,
    source: 'Fire in the hole!',
    reading: 'Ложись!',
  );
  const vault = GlossaryEntry(kind: GlossaryKind.word, source: 'Хранилище', reading: 'Убежище');
  final fallout = GlossaryPack(
    id: 'fallout',
    name: 'Fallout',
    entryKeys: [fire.packKey, vault.packKey],
    active: true,
  );
  final written = Glossary(entries: const [fire, vault], packs: [fallout]);

  late MemoryGlossary file;
  late TellingEngine engine;
  late GlossaryRepository glossary;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    file = MemoryGlossary()..stored = written;
    engine = TellingEngine();
    glossary = GlossaryRepository(SettingsRepository(SettingsService()), engine, file);
  });

  tearDown(() => glossary.dispose());

  test('reads the file once, whoever asks first, and publishes what it read', () async {
    final published = <Glossary>[];
    glossary.changes.listen(published.add);

    final first = await glossary.load();
    file.stored = Glossary.empty;
    final second = await glossary.load();

    expect(first.entries, [fire, vault]);
    expect(second, same(first));
    expect(published.single, same(first));
  });

  test('publishes a write at once, before the file has it', () async {
    final published = <Glossary>[];
    glossary.changes.listen(published.add);
    final edited = written.keeping(
      const GlossaryEntry(kind: GlossaryKind.phrase, source: 'Reloading!', reading: 'Перезарядка!'),
    );

    final saving = glossary.save(edited);

    expect(published.single, same(edited), reason: 'the screen that wrote it follows it');
    await saving;
    expect(file.stored, same(edited));
  });

  test('puts back what was there when the write fails', () async {
    glossary.seed(written);
    file.failure = StateError('disk full');

    await expectLater(glossary.save(Glossary.empty), throwsStateError);

    expect(glossary.glossary, same(written));
  });

  test('tells a running session what the canvas lets each pack apply', () async {
    glossary.seed(written);

    await glossary.narrow({
      'fallout': {GlossaryKind.name, GlossaryKind.word},
    });

    expect(engine.glossaries.single.entries, [vault], reason: 'a word is met on the translation');

    await glossary.narrow({
      'fallout': {GlossaryKind.word, GlossaryKind.name},
    });
    expect(engine.glossaries, hasLength(1), reason: 'the same reach is not told twice');
  });

  test('reads the screen session by the Screen page\'s canvas, not by Эфир\'s', () async {
    glossary.seed(written);
    engine.running = PipelineSession.screen;
    await glossary.narrow({
      'fallout': {GlossaryKind.phrase},
    });
    expect(engine.glossaries, isEmpty, reason: 'Эфир\'s canvas does not draw that session');

    await glossary.narrow({
      'fallout': {GlossaryKind.word},
    }, scheme: PipelineScheme.screen);
    expect(engine.glossaries.single.entries, [vault]);

    await glossary.save(written.activating('fallout', active: true));
    expect(engine.glossaries.last.entries, [vault], reason: 'an entry written keeps the reach');
  });

  test('reads a pack whole in a screen session its canvas says nothing of', () async {
    glossary.seed(written);
    engine.running = PipelineSession.screen;

    await glossary.save(written.activating('fallout', active: true));

    expect(engine.glossaries.last.entries, [fire, vault]);
  });

  test('tells no session while the engine rests', () async {
    glossary.seed(written);
    engine.running = null;

    await glossary.narrow({
      'fallout': {GlossaryKind.phrase},
    });

    expect(engine.glossaries, isEmpty);
  });
}
