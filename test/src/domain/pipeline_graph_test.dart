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
      expect(graph.node(recognition)!.bypassed, isFalse);
    });

    test('goes round whisper when the subtitles are read off the screen', () {
      final graph = buildPipelineGraph(
        settings: const AppSettings(captureMode: CaptureMode.ocr),
        characters: const [],
      );

      expect(
        joined(
          graph,
          const PipelinePort(source, PipelineSocket.screenText),
          const PipelinePort(translation, PipelineSocket.translationIn),
        ),
        isTrue,
      );
      expect(
        graph.links.any((link) => link.to.nodeId == recognition),
        isFalse,
        reason: 'nothing reaches a stage that takes no part',
      );
      expect(graph.node(recognition)!.bypassed, isTrue);
      expect(graph.node(recognition), isNotNull, reason: 'still drawn, so it can be put back');
    });
  });

  group('the cast on the canvas', () {
    test('takes nothing in while nobody lends the card a voice', () {
      final graph = buildPipelineGraph(
        settings: const AppSettings(),
        characters: const [guard],
        layout: const PipelineLayout(characters: ['guard']),
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
        layout: const PipelineLayout(characters: ['guard', 'smith']),
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
        layout: const PipelineLayout(characters: ['guard']),
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
        layout: const PipelineLayout(characters: ['guard', 'smith']),
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
        layout: const PipelineLayout(characters: ['guard', 'smith', 'cook']),
      );

      expect(graph.chained, {'guard'});
    });
  });

  group('what a link would change', () {
    PipelineGraph ocrGraph() => buildPipelineGraph(
      settings: const AppSettings(captureMode: CaptureMode.ocr),
      characters: const [guard, smith],
      layout: const PipelineLayout(characters: ['guard', 'smith']),
    );

    test('the way in, when the sound is taken back to whisper', () {
      final connection = proposeConnection(
        ocrGraph(),
        const PipelinePort(source, PipelineSocket.gameAudio),
        const PipelinePort(recognition, PipelineSocket.speechIn),
      );

      expect(connection, isA<RouteConnection>());
      expect((connection as RouteConnection).mode, CaptureMode.audio);
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
        ocrGraph(),
        const PipelinePort(source, PipelineSocket.screenText),
        const PipelinePort(recognition, PipelineSocket.speechIn),
      );

      expect((connection as RefusedConnection).reason, ConnectionRefusal.signal);
    });

    test('is refused between two outputs, and on one node', () {
      final graph = ocrGraph();

      expect(
        (proposeConnection(
          graph,
          const PipelinePort(source, PipelineSocket.screenText),
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
        ocrGraph(),
        const PipelinePort(source, PipelineSocket.screenText),
        const PipelinePort(voice, PipelineSocket.voiceIn),
      );

      expect((connection as RefusedConnection).reason, ConnectionRefusal.unsupported);
    });

    test('whose voice reads whom, between two cards', () {
      final connection = proposeConnection(
        ocrGraph(),
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
        layout: const PipelineLayout(characters: ['guard', 'smith']),
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
        layout: const PipelineLayout(characters: ['guard', 'smith']),
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
          settings: const AppSettings(captureMode: CaptureMode.ocr),
          characters: const [],
        ),
        const PipelinePort(recognition, PipelineSocket.speechIn),
        const PipelinePort(source, PipelineSocket.gameAudio),
      );

      expect((connection as RouteConnection).mode, CaptureMode.audio);
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

    test('is refused on the route, which is changed by drawing the other one', () {
      final connection = proposeDisconnect(
        const PipelineLink(
          PipelinePort(translation, PipelineSocket.translatedText),
          PipelinePort(voice, PipelineSocket.voiceIn),
        ),
      );

      expect((connection as RefusedConnection).reason, ConnectionRefusal.unsupported);
    });

    test('is refused on the voice a card sends to the mix', () {
      final connection = proposeDisconnect(
        PipelineLink(
          PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.characterVoice),
          const PipelinePort(mix, PipelineSocket.mixCast),
        ),
      );

      expect(
        (connection as RefusedConnection).reason,
        ConnectionRefusal.unsupported,
        reason: 'everything voiced is played; there is nothing to switch off',
      );
    });
  });

  group('the arrangement', () {
    test('comes back as it was written', () {
      const layout = PipelineLayout(
        positions: {source: GraphPoint(12, 34), 'character:guard': GraphPoint(-8, 900)},
        characters: ['guard'],
        view: GraphView(x: 40, y: -20, zoom: 0.8),
      );

      final read = PipelineLayout.fromJson(layout.toJson());

      expect(read.positions[source], const GraphPoint(12, 34));
      expect(read.positions['character:guard'], const GraphPoint(-8, 900));
      expect(read.characters, ['guard']);
      expect(read.view.x, 40);
      expect(read.view.zoom, 0.8);
    });

    test('falls back to the standard one when the file says nothing', () {
      expect(PipelineLayout.fromJson('rubbish').positions, PipelineLayout.standardPositions);
      expect(PipelineLayout.fromJson(const <String, Object?>{}).characters, isEmpty);
    });

    test('forgets a card together with where it was put', () {
      const layout = PipelineLayout(
        positions: {'character:guard': GraphPoint(1, 2)},
        characters: ['guard', 'smith'],
      );

      final without = layout.withoutCharacter('guard');

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
      expect(graph.node(id)?.bypassed, isFalse, reason: 'unrouted is not passed over: $id');
    }
    // What runs between the stages is the pipeline itself and stays drawn.
    expect(
      graph.linkInto(const PipelinePort(PipelineNodeIds.voice, PipelineSocket.voiceIn)),
      isNotNull,
    );
  });

  test('cutting the way in asks for no route rather than for the other one', () {
    final graph = buildPipelineGraph(settings: const AppSettings(), characters: const []);
    final route = graph.linkInto(
      const PipelinePort(PipelineNodeIds.recognition, PipelineSocket.speechIn),
    )!;

    expect(
      proposeDisconnect(route),
      isA<RouteConnection>().having((connection) => connection.mode, 'mode', isNull),
    );
  });
}
