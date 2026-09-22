// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/glossary.dart';
import 'package:lore_dub/src/domain/pipeline_graph.dart';

/// The line of text on the canvas and the switches of the glossary: a pack
/// follows the line, and the line stays where it is drawn whatever the
/// switches say.
void main() {
  const fire = GlossaryEntry(
    kind: GlossaryKind.phrase,
    source: 'Fire in the hole!',
    reading: 'Ложись!',
  );
  const vault = GlossaryEntry(kind: GlossaryKind.word, source: 'Хранилище', reading: 'Убежище');
  final lines = GlossaryPack(id: 'lines', name: 'Реплики', entryKeys: [fire.packKey]);
  final fallout = GlossaryPack(id: 'fallout', name: 'Fallout', entryKeys: [vault.packKey]);
  final written = Glossary(entries: const [fire, vault], packs: [lines, fallout]);
  final first = PipelineNodeIds.glossary(1);
  final second = PipelineNodeIds.glossary(2);

  bool on(Glossary glossary, String id) => glossary.packWithId(id)!.active;

  group('an edit on the canvas', () {
    test('switches on a pack it put in the line, and off one it took out', () {
      final before = PipelineLayout.standard
          .withGlossary('lines', feed: GlossaryFeed.recognition)
          .withGlossary('fallout');
      final edited = before.withLine([
        LineRemove({first}),
        LineMove(second, anchor: PipelineNodeIds.voice, after: false),
      ], translates: true);

      final switched = packsFollowingLine(
        written.activating('lines', active: true),
        before,
        edited,
      );

      expect(on(switched, 'lines'), isFalse);
      expect(on(switched, 'fallout'), isTrue);
    });

    test('leaves a pack switched as it was while another of its drawings stands in the line', () {
      final before = PipelineLayout.standard
          .withGlossary('fallout', feed: GlossaryFeed.recognition)
          .withGlossary('fallout', feed: GlossaryFeed.translation);
      final glossary = written.activating('fallout', active: true);

      final switched = packsFollowingLine(
        glossary,
        before,
        before.withLine([
          LineRemove({first}),
        ], translates: true),
      );

      expect(switched, same(glossary));
    });

    test('switches off a pack whose last drawing in the line is taken off the canvas', () {
      final before = PipelineLayout.standard.withGlossary(
        'fallout',
        feed: GlossaryFeed.translation,
      );

      final switched = packsFollowingLine(
        written.activating('fallout', active: true),
        before,
        before.withoutNode(first),
      );

      expect(on(switched, 'fallout'), isFalse);
    });

    test('touches no pack it did not move', () {
      // Drawn out of the line while it is switched on: a drawing standing
      // aside says nothing of the switch, which the pack keeps.
      final before = PipelineLayout.standard;
      final glossary = written.activating('lines', active: true);

      expect(
        packsFollowingLine(glossary, before, before.withGlossary('lines')),
        same(glossary),
      );
    });

    test('leaves a pack switched off where the edit only moved it along the line', () {
      // Switched off on its node, a pack stays in the line and the text goes
      // past it; carried to the other side of the translator, it is still
      // the player's to switch back on.
      final before = PipelineLayout.standard.withGlossary(
        'fallout',
        feed: GlossaryFeed.recognition,
      );

      expect(
        packsFollowingLine(
          written,
          before,
          before.withLine([
            LineMove(first, anchor: PipelineNodeIds.voice, after: false),
          ], translates: true),
        ),
        same(written),
      );
    });
  });

  test('tells one drawing, and one edit of the line, from another by value', () {
    final drawing = GlossaryPlacement(
      nodeId: first,
      packId: 'lines',
      feed: GlossaryFeed.recognition,
    );
    expect({drawing, GlossaryPlacement.fromJson(drawing.toJson())}, hasLength(1));
    expect(drawing, isNot(drawing.copyWith(unfed: true)));
    expect('$drawing', contains('recognition'));
    expect('${drawing.copyWith(unfed: true)}', isNot(contains('recognition')));

    final move = LineMove(first, anchor: PipelineNodeIds.voice, after: false);
    expect({move, LineMove(first, anchor: PipelineNodeIds.voice, after: false)}, hasLength(1));
    expect(move, isNot(LineMove(first, anchor: PipelineNodeIds.voice, after: true)));
    expect('$move', 'LineMove($first before ${PipelineNodeIds.voice})');

    final remove = LineRemove({first, second});
    expect(
      {
        remove,
        LineRemove({second, first}),
      },
      hasLength(1),
      reason: 'the order says nothing',
    );
    expect(remove, isNot(LineRemove({first})));
    expect('$remove', contains(second));
  });

  test('switches exactly the packs a scheme names, and passes over the rest', () {
    final switched = written.activating('lines', active: true).switchedTo({'fallout', 'other'});

    expect(on(switched, 'lines'), isFalse);
    expect(on(switched, 'fallout'), isTrue);
    expect(written.switchedTo(const {}), same(written), reason: 'nothing had to be switched');
  });
}
