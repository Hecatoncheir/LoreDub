// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/character.dart';
import 'package:lore_dub/src/domain/pipeline_graph.dart';

void main() {
  const guard = Character(id: 'guard', name: 'Стражник', vector: [0.2, 0.4]);
  const smith = Character(id: 'smith', name: 'Кузнец', vector: [0.1, 0.9]);

  const source = PipelineNodeIds.source;
  const recognition = PipelineNodeIds.recognition;
  const translation = PipelineNodeIds.translation;
  const voice = PipelineNodeIds.voice;
  const mix = PipelineNodeIds.mix;
  const output = PipelineNodeIds.output;

  bool joined(PipelineGraph graph, PipelinePort from, PipelinePort to) =>
      graph.links.contains(PipelineLink(from, to));

  group('the route', () {
    test('goes through whisper when the game is heard', () {
      final graph = buildPipelineGraph(settings: const AppSettings(), characters: const []);

      expect(
        joined(
          graph,
          const PipelinePort(source, PipelineSocket.gameAudio),
          const PipelinePort(recognition, PipelineSocket.speechIn),
        ),
        isTrue,
      );
      expect(
        joined(
          graph,
          const PipelinePort(recognition, PipelineSocket.speechText),
          const PipelinePort(translation, PipelineSocket.translationIn),
        ),
        isTrue,
      );
      expect(
        joined(
          graph,
          const PipelinePort(translation, PipelineSocket.translatedText),
          const PipelinePort(voice, PipelineSocket.voiceIn),
        ),
        isTrue,
      );
      expect(
        joined(
          graph,
          const PipelinePort(voice, PipelineSocket.voiceAudio),
          const PipelinePort(mix, PipelineSocket.mixIn),
        ),
        isTrue,
      );
      expect(
        joined(
          graph,
          const PipelinePort(mix, PipelineSocket.mixOut),
          const PipelinePort(output, PipelineSocket.streamIn),
        ),
        isTrue,
      );
    });

    test('leaves every stage in the one route the engine runs', () {
      final graph = buildPipelineGraph(settings: const AppSettings(), characters: const []);

      expect(
        graph.links.any((link) => link.to.nodeId == recognition),
        isTrue,
        reason: 'the sound is recognized before it is translated',
      );
      expect(graph.nodes.any((node) => node.unrouted), isFalse);
    });
  });

  group('the cast on the canvas', () {
    test('takes nothing in while nobody lends the card a voice', () {
      final graph = buildPipelineGraph(
        settings: const AppSettings(),
        characters: const [guard],
        layout: PipelineLayout.drawing(['guard']),
      );

      // The cast reaches every card that is drawn: that socket is the one
      // that is never empty.
      expect(
        graph
            .linkInto(
              PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.characterIn),
            )
            ?.from,
        const PipelinePort(PipelineNodeIds.voice, PipelineSocket.voiceCast),
      );

      // The socket takes a voice but does not ask for one: read in its own,
      // a card has nothing arriving, and that is what says so.
      expect(
        graph.linkInto(
          PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.readBy),
        ),
        isNull,
      );
      // Its own voice goes on to the mix, which is its one way out.
      expect(
        joined(
          graph,
          PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.characterVoice),
          const PipelinePort(PipelineNodeIds.mix, PipelineSocket.mixCast),
        ),
        isTrue,
      );
    });

    test('sends every card on to be put in order with the rest', () {
      final graph = buildPipelineGraph(
        settings: const AppSettings(),
        characters: const [guard, smith],
        layout: PipelineLayout.drawing(['guard', 'smith']),
      );

      for (final id in ['guard', 'smith']) {
        expect(
          joined(
            graph,
            PipelinePort(PipelineNodeIds.character(id), PipelineSocket.characterVoice),
            const PipelinePort(mix, PipelineSocket.mixCast),
          ),
          isTrue,
          reason: 'a card on the canvas is part of the path, not an island beside it',
        );
      }
    });

    test('leaves the reader socket empty when the reader is off the canvas', () {
      final graph = buildPipelineGraph(
        settings: const AppSettings(),
        characters: const [
          Character(id: 'guard', name: 'Стражник', vector: [0.2], voicedBy: 'smith'),
          smith,
        ],
        layout: PipelineLayout.drawing(['guard']),
      );

      // Only what the player put there is drawn, so a card can always be
      // taken off — even one another card is read in the voice of.
      expect(graph.node(PipelineNodeIds.character('smith')), isNull);
      // And nothing runs into the reader socket. A line out of the voice
      // node would say nobody had replaced them, which is not so: the card
      // says whose voice reads it on its own face.
      expect(
        graph.linkInto(
          PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.readBy),
        ),
        isNull,
      );
      // It lends its voice to nobody who is drawn, so its own way out is
      // the mix, as it would be for a card nobody replaced.
      expect(
        joined(
          graph,
          PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.characterVoice),
          const PipelinePort(PipelineNodeIds.mix, PipelineSocket.mixCast),
        ),
        isTrue,
      );
    });

    test('lets a lent voice out one way only', () {
      final graph = buildPipelineGraph(
        settings: const AppSettings(),
        characters: const [
          Character(id: 'guard', name: 'Стражник', vector: [0.2], voicedBy: 'smith'),
          smith,
        ],
        layout: PipelineLayout.drawing(['guard', 'smith']),
      );

      // Both cards are in the cast whoever reads whom.
      for (final id in ['guard', 'smith']) {
        expect(
          graph
              .linkInto(
                PipelinePort(PipelineNodeIds.character(id), PipelineSocket.characterIn),
              )
              ?.from,
          const PipelinePort(PipelineNodeIds.voice, PipelineSocket.voiceCast),
          reason: id,
        );
      }

      final part = PipelinePort(
        PipelineNodeIds.character('guard'),
        PipelineSocket.characterVoice,
      );
      // Into the card it reads, and nowhere else: that card carries it on.
      expect(graph.links.where((link) => link.from == part).length, 1);
      expect(
        joined(
          graph,
          part,
          PipelinePort(PipelineNodeIds.character('smith'), PipelineSocket.readBy),
        ),
        isTrue,
      );
      expect(
        joined(graph, part, const PipelinePort(PipelineNodeIds.mix, PipelineSocket.mixCast)),
        isFalse,
        reason: 'it is spoken by the other card, which carries it on',
      );
      // And that card is the one the mix hears.
      expect(
        joined(
          graph,
          PipelinePort(PipelineNodeIds.character('smith'), PipelineSocket.characterVoice),
          const PipelinePort(PipelineNodeIds.mix, PipelineSocket.mixCast),
        ),
        isTrue,
      );
    });

    test('marks a card whose reader is read by a third', () {
      final graph = buildPipelineGraph(
        settings: const AppSettings(),
        characters: const [
          Character(id: 'guard', name: 'Стражник', vector: [0.2], voicedBy: 'smith'),
          Character(id: 'smith', name: 'Кузнец', vector: [0.1], voicedBy: 'cook'),
          Character(id: 'cook', name: 'Повар', vector: [0.5]),
        ],
        layout: PipelineLayout.drawing(['guard', 'smith', 'cook']),
      );

      expect(graph.chained, {'guard'});
    });

    test('marks the cards the mix hears rather than the ones handing a part on', () {
      final graph = buildPipelineGraph(
        settings: const AppSettings(),
        characters: const [
          Character(id: 'guard', name: 'Стражник', vector: [0.2], voicedBy: 'smith'),
          smith,
        ],
        layout: PipelineLayout.drawing(['guard', 'smith']),
      );

      // What the player hears is the reader, and the canvas says so: the
      // card handing its part on is not the voice that comes out.
      expect(graph.node(PipelineNodeIds.character('smith'))?.sendsToMix, isTrue);
      expect(graph.node(PipelineNodeIds.character('guard'))?.sendsToMix, isFalse);
    });

    test('marks nobody once every card is cut out of the mix', () {
      final graph = buildPipelineGraph(
        settings: const AppSettings(),
        characters: const [guard, smith],
        layout: PipelineLayout.drawing([
          'guard',
          'smith',
        ]).withVoiced('guard', false).withVoiced('smith', false),
      );

      for (final id in ['guard', 'smith']) {
        expect(graph.node(PipelineNodeIds.character(id))?.sendsToMix, isFalse);
      }
    });
  });

  group('the translator', () {
    const english = AppSettings(targetLanguage: 'en');

    test('stands aside, with the text going past it, when nothing translates', () {
      final graph = buildPipelineGraph(settings: english, characters: const []);

      expect(graph.node(translation)?.unrouted, isTrue);
      expect(
        joined(
          graph,
          const PipelinePort(recognition, PipelineSocket.speechText),
          const PipelinePort(voice, PipelineSocket.voiceIn),
        ),
        isTrue,
      );
      expect(
        joined(
          graph,
          const PipelinePort(recognition, PipelineSocket.speechText),
          const PipelinePort(translation, PipelineSocket.translationIn),
        ),
        isFalse,
      );
      expect(
        joined(
          graph,
          const PipelinePort(translation, PipelineSocket.translatedText),
          const PipelinePort(voice, PipelineSocket.voiceIn),
        ),
        isFalse,
      );
    });

    test('stands in the line for a language that has one', () {
      final graph = buildPipelineGraph(settings: const AppSettings(), characters: const []);

      expect(graph.node(translation)?.unrouted, isFalse);
    });

    test('is drawn faded with the rest while the way in is cut', () {
      final graph = buildPipelineGraph(
        settings: const AppSettings(targetLanguage: 'en', captureRouted: false),
        characters: const [],
      );

      // Nothing reaches the stages at all, so the line that steps over the
      // translator is not drawn either.
      expect(graph.node(translation)?.unrouted, isTrue);
      expect(
        joined(
          graph,
          const PipelinePort(recognition, PipelineSocket.speechText),
          const PipelinePort(voice, PipelineSocket.voiceIn),
        ),
        isFalse,
      );
    });
  });

  group('what a link would change', () {
    PipelineGraph cutGraph() => buildPipelineGraph(
      settings: const AppSettings(captureRouted: false),
      characters: const [guard, smith],
      layout: PipelineLayout.drawing(['guard', 'smith']),
    );

    test('the way in, when the sound is taken back to whisper', () {
      final connection = proposeConnection(
        cutGraph(),
        const PipelinePort(source, PipelineSocket.gameAudio),
        const PipelinePort(recognition, PipelineSocket.speechIn),
      );

      expect(connection, isA<RouteConnection>());
      expect((connection as RouteConnection).routed, isTrue);
    });

    test('nothing at all, when the link is already drawn', () {
      final connection = proposeConnection(
        buildPipelineGraph(settings: const AppSettings(), characters: const []),
        const PipelinePort(source, PipelineSocket.gameAudio),
        const PipelinePort(recognition, PipelineSocket.speechIn),
      );

      expect(connection, isA<UnchangedConnection>());
    });

    test('is refused when the two ends carry different things', () {
      final connection = proposeConnection(
        cutGraph(),
        const PipelinePort(source, PipelineSocket.gameAudio),
        const PipelinePort(translation, PipelineSocket.translationIn),
      );

      expect((connection as RefusedConnection).reason, ConnectionRefusal.signal);
    });

    test('is refused between two outputs, and on one node', () {
      final graph = cutGraph();

      expect(
        (proposeConnection(
          graph,
          const PipelinePort(source, PipelineSocket.gameAudio),
          const PipelinePort(recognition, PipelineSocket.speechText),
        ) as RefusedConnection).reason,
        ConnectionRefusal.direction,
      );
      expect(
        (proposeConnection(
          graph,
          const PipelinePort(voice, PipelineSocket.voiceAudio),
          const PipelinePort(voice, PipelineSocket.voiceIn),
        ) as RefusedConnection).reason,
        ConnectionRefusal.sameNode,
      );
    });

    test('is refused where the engine has no route', () {
      final connection = proposeConnection(
        cutGraph(),
        const PipelinePort(source, PipelineSocket.gameAudio),
        const PipelinePort(mix, PipelineSocket.mixIn),
      );

      expect((connection as RefusedConnection).reason, ConnectionRefusal.unsupported);
    });

    test('the translator stepped over, when whisper is taken to the voice', () {
      final connection = proposeConnection(
        cutGraph(),
        const PipelinePort(recognition, PipelineSocket.speechText),
        const PipelinePort(voice, PipelineSocket.voiceIn),
      );

      expect((connection as TranslationConnection).routed, isFalse);
    });

    test('the translator back in the line, drawn at either end of it', () {
      final english = buildPipelineGraph(
        settings: const AppSettings(targetLanguage: 'en'),
        characters: const [],
      );

      expect(
        (proposeConnection(
          english,
          const PipelinePort(recognition, PipelineSocket.speechText),
          const PipelinePort(translation, PipelineSocket.translationIn),
        ) as TranslationConnection).routed,
        isTrue,
      );
      expect(
        (proposeConnection(
          english,
          const PipelinePort(translation, PipelineSocket.translatedText),
          const PipelinePort(voice, PipelineSocket.voiceIn),
        ) as TranslationConnection).routed,
        isTrue,
      );
    });

    test('whose voice reads whom, between two cards', () {
      final connection = proposeConnection(
        cutGraph(),
        PipelinePort(PipelineNodeIds.character('smith'), PipelineSocket.characterVoice),
        PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.readBy),
        characters: const [guard, smith],
      );

      expect(connection, isA<ReaderConnection>());
      // The line runs out of the card whose part it is and into the card
      // that will speak it: «Кузнец» is read by «Стражник», not the reverse.
      expect((connection as ReaderConnection).characterId, 'smith');
      expect(connection.readerId, 'guard');
    });

    test('is refused when two cards would read each other', () {
      const given = Character(id: 'smith', name: 'Кузнец', vector: [0.1], voicedBy: 'guard');
      final graph = buildPipelineGraph(
        settings: const AppSettings(),
        characters: const [guard, given],
        layout: PipelineLayout.drawing(['guard', 'smith']),
      );

      final connection = proposeConnection(
        graph,
        PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.characterVoice),
        PipelinePort(PipelineNodeIds.character('smith'), PipelineSocket.readBy),
        characters: const [guard, given],
      );

      expect((connection as RefusedConnection).reason, ConnectionRefusal.loop);
    });

    test('the card back to its own voice, when the pipeline reads it again', () {
      const given = Character(id: 'guard', name: 'Стражник', vector: [0.2], voicedBy: 'smith');
      final graph = buildPipelineGraph(
        settings: const AppSettings(),
        characters: const [given, smith],
        layout: PipelineLayout.drawing(['guard', 'smith']),
      );

      // The voice comes back by cutting the line that lent it, there being
      // nothing to draw from: a card reads in its own voice when its socket
      // is empty.
      final connection = proposeDisconnect(
        graph.links.firstWhere(
          (link) =>
              link.from ==
              PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.characterVoice),
        ),
      );

      expect((connection as ReaderConnection).characterId, 'guard');
      expect(connection.readerId, isNull);
    });

    test('is read the same way round when it is dragged backwards', () {
      final connection = proposeConnection(
        buildPipelineGraph(
          settings: const AppSettings(captureRouted: false),
          characters: const [],
        ),
        const PipelinePort(recognition, PipelineSocket.speechIn),
        const PipelinePort(source, PipelineSocket.gameAudio),
      );

      expect((connection as RouteConnection).routed, isTrue);
    });
  });

  group('cutting a link', () {
    test('gives a card its own voice back', () {
      final connection = proposeDisconnect(
        PipelineLink(
          PipelinePort(PipelineNodeIds.character('smith'), PipelineSocket.characterVoice),
          PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.readBy),
        ),
      );

      expect((connection as ReaderConnection).characterId, 'smith');
      expect(connection.readerId, isNull);
    });

    test('the translator out of the line, by either half of it', () {
      for (final link in const [
        PipelineLink(
          PipelinePort(recognition, PipelineSocket.speechText),
          PipelinePort(translation, PipelineSocket.translationIn),
        ),
        PipelineLink(
          PipelinePort(translation, PipelineSocket.translatedText),
          PipelinePort(voice, PipelineSocket.voiceIn),
        ),
      ]) {
        expect((proposeDisconnect(link) as TranslationConnection).routed, isFalse);
      }
    });

    test('the translator back in, rather than a voice with nothing to read', () {
      // The line that steps over the stage carries the only text the voice
      // gets, so cutting it can only mean putting the stage back.
      final connection = proposeDisconnect(
        const PipelineLink(
          PipelinePort(recognition, PipelineSocket.speechText),
          PipelinePort(voice, PipelineSocket.voiceIn),
        ),
      );

      expect((connection as TranslationConnection).routed, isTrue);
    });

    test('takes one card out of the mix, by the line that is cut', () {
      final connection = proposeDisconnect(
        PipelineLink(
          PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.characterVoice),
          const PipelinePort(mix, PipelineSocket.mixCast),
        ),
      );

      expect((connection as CastConnection).characterId, 'guard');
      expect(connection.routed, isFalse);
    });

    test('names the card a copy stands for, not the copy', () {
      // Every drawing of a card answers together: the mix is told a
      // character once however many times it is drawn.
      final connection = proposeDisconnect(
        PipelineLink(
          PipelinePort(
            PipelineNodeIds.characterCopy('guard', 2),
            PipelineSocket.characterVoice,
          ),
          const PipelinePort(mix, PipelineSocket.mixCast),
        ),
      );

      expect((connection as CastConnection).characterId, 'guard');
    });

    test('and the line drawn back wakes that card again', () {
      final connection = proposeConnection(
        buildPipelineGraph(
          settings: const AppSettings(),
          characters: const [guard],
          layout: PipelineLayout.drawing(['guard']).withVoiced('guard', false),
        ),
        PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.characterVoice),
        const PipelinePort(mix, PipelineSocket.mixCast),
        characters: const [guard],
      );

      expect((connection as CastConnection).characterId, 'guard');
      expect(connection.routed, isTrue);
    });

    test('un-cuts a card taken off the canvas altogether', () {
      // A card the scheme does not draw is voiced the way it always was:
      // the cut is a line on the scheme, and there is no line to cut.
      final layout = PipelineLayout.drawing(['guard', 'smith']).withVoiced('smith', false);

      expect(layout.withoutNode(PipelineNodeIds.character('smith')).silent, isEmpty);
      expect(
        layout.withoutNode(PipelineNodeIds.character('guard')).silent,
        {'smith'},
        reason: 'the card that is still drawn keeps its cut',
      );
    });

    test('leaves a cut card drawn but dark, and the rest of the cast alone', () {
      final graph = buildPipelineGraph(
        settings: const AppSettings(),
        characters: const [
          Character(id: 'guard', name: 'Стражник', vector: [0.2], voicedBy: 'smith'),
          smith,
        ],
        layout: PipelineLayout.drawing(['guard', 'smith']).withVoiced('smith', false),
      );

      final cut = graph.node(PipelineNodeIds.character('smith'))!;
      expect(cut.unrouted, isTrue, reason: 'the card stays where it was put');
      expect(
        graph.links.any((link) => link.from.nodeId == cut.id || link.to.nodeId == cut.id),
        isFalse,
        reason: 'and nothing runs through it',
      );

      // The card it read is untouched and speaks for itself again: read by
      // nobody, its own line goes on to the mix.
      final left = graph.node(PipelineNodeIds.character('guard'))!;
      expect(left.unrouted, isFalse);
      expect(
        joined(
          graph,
          PipelinePort(left.id, PipelineSocket.characterVoice),
          const PipelinePort(mix, PipelineSocket.mixCast),
        ),
        isTrue,
      );
    });
  });

  group('a card drawn more than once', () {
    /// The same card twice, the copy put away to the right of the first.
    PipelineLayout twice(String characterId, {bool heard = true}) => PipelineLayout(
      cast: [
        CastPlacement.of(characterId, heard: heard),
        CastPlacement(
          nodeId: PipelineNodeIds.characterCopy(characterId, 2),
          characterId: characterId,
          heard: false,
        ),
      ],
      positions: {
        PipelineNodeIds.character(characterId): const GraphPoint(600, 500),
        PipelineNodeIds.characterCopy(characterId, 2): const GraphPoint(1600, 500),
      },
    );

    test('is drawn as many nodes as it was put on the canvas', () {
      final graph = buildPipelineGraph(
        settings: const AppSettings(),
        characters: const [guard],
        layout: twice('guard'),
      );

      expect(graph.ofKind(PipelineNodeKind.character).length, 2);
      for (final node in graph.ofKind(PipelineNodeKind.character)) {
        expect(node.characterId, 'guard', reason: 'both drawings are the same card');
      }
    });

    test('is counted among the voices of the game once', () {
      final graph = buildPipelineGraph(
        settings: const AppSettings(),
        characters: const [guard],
        layout: twice('guard'),
      );

      expect(
        graph.linkInto(
          PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.characterIn),
        ),
        isNotNull,
      );
      // The copy is drawn to take a part over, not to be heard a second
      // time, so nothing arrives at it and nothing leaves it either.
      expect(
        graph.linkInto(
          PipelinePort(PipelineNodeIds.characterCopy('guard', 2), PipelineSocket.characterIn),
        ),
        isNull,
      );
      expect(
        joined(
          graph,
          PipelinePort(PipelineNodeIds.characterCopy('guard', 2), PipelineSocket.characterVoice),
          const PipelinePort(mix, PipelineSocket.mixCast),
        ),
        isFalse,
      );
    });

    test('takes the part into the copy the player put beside it', () {
      // The smith is read by the guard, whose card is drawn twice: once by
      // the pipeline, once beside the smith. The line is meant for the near
      // one -- that is what the second drawing is for.
      final graph = buildPipelineGraph(
        settings: const AppSettings(),
        characters: const [
          guard,
          Character(id: 'smith', name: 'Кузнец', vector: [], voicedBy: 'guard'),
        ],
        layout: PipelineLayout(
          cast: [
            CastPlacement.of('guard'),
            CastPlacement(
              nodeId: PipelineNodeIds.characterCopy('guard', 2),
              characterId: 'guard',
              heard: false,
            ),
            CastPlacement.of('smith'),
          ],
          positions: {
            PipelineNodeIds.character('guard'): const GraphPoint(0, 0),
            PipelineNodeIds.characterCopy('guard', 2): const GraphPoint(900, 500),
            PipelineNodeIds.character('smith'): const GraphPoint(620, 500),
          },
        ),
      );

      expect(
        joined(
          graph,
          PipelinePort(PipelineNodeIds.character('smith'), PipelineSocket.characterVoice),
          PipelinePort(PipelineNodeIds.characterCopy('guard', 2), PipelineSocket.readBy),
        ),
        isTrue,
      );
      // What the copy takes over it carries on, the way the card it stands
      // for would have.
      expect(
        joined(
          graph,
          PipelinePort(PipelineNodeIds.characterCopy('guard', 2), PipelineSocket.characterVoice),
          const PipelinePort(mix, PipelineSocket.mixCast),
        ),
        isTrue,
      );
    });

    test('cannot be read by itself', () {
      final graph = buildPipelineGraph(
        settings: const AppSettings(),
        characters: const [guard],
        layout: twice('guard'),
      );

      expect(
        proposeConnection(
          graph,
          PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.characterVoice),
          PipelinePort(PipelineNodeIds.characterCopy('guard', 2), PipelineSocket.readBy),
          characters: const [guard],
        ),
        isA<RefusedConnection>().having(
          (refusal) => refusal.reason,
          'reason',
          ConnectionRefusal.loop,
        ),
      );
    });
  });

  group('a card the game never speaks', () {
    test('is drawn without the line that says it may be heard', () {
      final graph = buildPipelineGraph(
        settings: const AppSettings(),
        characters: const [guard],
        layout: PipelineLayout(cast: [CastPlacement.of('guard', heard: false)]),
      );

      expect(
        graph.linkInto(
          PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.characterIn),
        ),
        isNull,
      );
      // Nothing of its own to send, and nothing arriving to carry on: the
      // card is there to lend its voice and nothing else.
      expect(
        joined(
          graph,
          PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.characterVoice),
          const PipelinePort(mix, PipelineSocket.mixCast),
        ),
        isFalse,
      );
    });

    test('still shows whose voice reads it', () {
      // A substitution nobody can see is a trap, whether or not the game
      // ever speaks the card it was set on.
      final graph = buildPipelineGraph(
        settings: const AppSettings(),
        characters: const [
          guard,
          Character(id: 'smith', name: 'Кузнец', vector: [], voicedBy: 'guard'),
        ],
        layout: PipelineLayout(
          cast: [CastPlacement.of('smith', heard: false), CastPlacement.of('guard')],
        ),
      );

      expect(
        joined(
          graph,
          PipelinePort(PipelineNodeIds.character('smith'), PipelineSocket.characterVoice),
          PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.readBy),
        ),
        isTrue,
      );
    });

    test('is counted in and out by the line itself', () {
      final graph = buildPipelineGraph(
        settings: const AppSettings(),
        characters: const [guard],
        layout: PipelineLayout.drawing(['guard']),
      );
      final counted = graph.linkInto(
        PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.characterIn),
      )!;

      expect(
        proposeDisconnect(counted),
        isA<HeardConnection>()
            .having((connection) => connection.nodeId, 'node', PipelineNodeIds.character('guard'))
            .having((connection) => connection.heard, 'heard', isFalse),
      );

      final without = buildPipelineGraph(
        settings: const AppSettings(),
        characters: const [guard],
        layout: PipelineLayout(cast: [CastPlacement.of('guard', heard: false)]),
      );
      expect(
        proposeConnection(
          without,
          const PipelinePort(voice, PipelineSocket.voiceCast),
          PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.characterIn),
          characters: const [guard],
        ),
        isA<HeardConnection>().having((connection) => connection.heard, 'heard', isTrue),
      );
    });
  });

  group('the arrangement', () {
    test('comes back as it was written', () {
      final layout = PipelineLayout.drawing(
        ['guard'],
        positions: const {source: GraphPoint(12, 34), 'character:guard': GraphPoint(-8, 900)},
        view: const GraphView(x: 40, y: -20, zoom: 0.8),
      );

      final read = PipelineLayout.fromJson(layout.toJson());

      expect(read.positions[source], const GraphPoint(12, 34));
      expect(read.positions['character:guard'], const GraphPoint(-8, 900));
      expect(read.characters, ['guard']);
      expect(read.view.x, 40);
      expect(read.view.zoom, 0.8);
    });

    test('keeps every drawing of a card, and which of them is heard', () {
      final layout = PipelineLayout(
        cast: [
          CastPlacement.of('guard'),
          CastPlacement(
            nodeId: PipelineNodeIds.characterCopy('guard', 2),
            characterId: 'guard',
            heard: false,
          ),
        ],
      );

      final read = PipelineLayout.fromJson(layout.toJson());

      expect(read.cast, layout.cast);
    });

    test('keeps the cards cut out of the mix', () {
      final layout = PipelineLayout.drawing(['guard', 'smith']).withVoiced('smith', false);

      expect(PipelineLayout.fromJson(layout.toJson()).silent, {'smith'});
      // A file from before the cut was a card's own names nobody: it had one
      // switch for the whole cast, and it lived in the settings.
      expect(
        PipelineLayout.fromJson(const {
          'version': 2,
          'cast': ['guard'],
        }).silent,
        isEmpty,
      );
    });

    test('reads a file from before a card could be drawn twice', () {
      final read = PipelineLayout.fromJson(const {
        'version': 1,
        'characters': ['guard', 'smith'],
      });

      expect(read.cast, [CastPlacement.of('guard'), CastPlacement.of('smith')]);
    });

    test('draws the second copy of a card without counting it in again', () {
      final layout = PipelineLayout.drawing(['guard']).withCharacter('guard');

      expect(layout.cast.length, 2);
      expect(layout.cast.last.nodeId, PipelineNodeIds.characterCopy('guard', 2));
      expect(layout.cast.last.heard, isFalse);
      expect(layout.cast.first.heard, isTrue);
    });

    test('falls back to the standard one when the file says nothing', () {
      expect(PipelineLayout.fromJson('rubbish').positions, PipelineLayout.standardPositions);
      expect(PipelineLayout.fromJson(const <String, Object?>{}).characters, isEmpty);
    });

    test('forgets a card together with where it was put', () {
      final layout = PipelineLayout.drawing(
        ['guard', 'smith'],
        positions: const {'character:guard': GraphPoint(1, 2)},
      );

      final without = layout.withoutNode('character:guard');

      expect(without.characters, ['smith']);
      expect(without.positions, isEmpty);
    });
  });

  group('the view', () {
    test('keeps what is under the pointer where it is', () {
      const view = GraphView(x: 100, y: 50);
      const pointer = GraphPoint(300, 200);

      final before = view.toCanvas(pointer);
      final after = view.zoomedAt(1.4, pointer).toCanvas(pointer);

      expect(after.x, closeTo(before.x, 0.0001));
      expect(after.y, closeTo(before.y, 0.0001));
    });

    test('does not zoom past what can be read', () {
      expect(const GraphView().zoomedAt(9, GraphPoint.zero).zoom, GraphView.largestZoom);
      expect(const GraphView().zoomedAt(0.01, GraphPoint.zero).zoom, GraphView.smallestZoom);
    });
  });

  test('draws nothing into a pipeline whose way in was taken apart', () {
    const settings = AppSettings(captureRouted: false);
    final graph = buildPipelineGraph(settings: settings, characters: const []);

    expect(graph.routed, isFalse);
    expect(
      graph.linkInto(const PipelinePort(PipelineNodeIds.recognition, PipelineSocket.speechIn)),
      isNull,
    );
    expect(
      graph.linkInto(const PipelinePort(PipelineNodeIds.translation, PipelineSocket.translationIn)),
      isNull,
    );
    for (final id in PipelineNodeIds.stages) {
      expect(graph.node(id)?.unrouted, isTrue, reason: id);
    }
    // What runs between the stages is the pipeline itself and stays drawn.
    expect(
      graph.linkInto(const PipelinePort(PipelineNodeIds.voice, PipelineSocket.voiceIn)),
      isNotNull,
    );
  });

  test('cutting the way in leaves the stages with nothing coming into them', () {
    final graph = buildPipelineGraph(settings: const AppSettings(), characters: const []);
    final route = graph.linkInto(
      const PipelinePort(PipelineNodeIds.recognition, PipelineSocket.speechIn),
    )!;

    expect(
      proposeDisconnect(route),
      isA<RouteConnection>().having((connection) => connection.routed, 'routed', isFalse),
    );
  });
}
