// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/character.dart';
import 'package:lore_dub/src/domain/glossary.dart';
import 'package:lore_dub/src/domain/pipeline_graph.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart';
import 'package:lore_dub/src/domain/saved_pipeline.dart';

/// The Screen page's scheme: the text read off the screen in a line to the
/// output, and the game's sound through the character detection into the
/// voice -- the same machine as Эфир's, over other stages.
void main() {
  const source = PipelineNodeIds.source;
  const detection = PipelineNodeIds.detection;
  const screen = PipelineNodeIds.screen;
  const translation = PipelineNodeIds.translation;
  const voice = PipelineNodeIds.voice;
  const mix = PipelineNodeIds.mix;
  const output = PipelineNodeIds.output;

  const gameAudio = PipelinePort(source, PipelineSocket.gameAudio);
  const intoDetection = PipelinePort(detection, PipelineSocket.detectionIn);
  const speaker = PipelinePort(detection, PipelineSocket.detectedSpeaker);
  const intoVoiceSpeaker = PipelinePort(voice, PipelineSocket.voiceSpeaker);
  const screenText = PipelinePort(screen, PipelineSocket.screenText);
  const intoTranslator = PipelinePort(translation, PipelineSocket.translationIn);
  const translated = PipelinePort(translation, PipelineSocket.translatedText);
  const intoVoice = PipelinePort(voice, PipelineSocket.voiceIn);

  /// English text off the screen, translated into Russian: what a fresh
  /// install reads.
  const translating = AppSettings();

  /// Russian text off the screen, read as it is.
  const readAsIs = AppSettings(screenLanguage: 'ru');

  PipelineGraph drawn({
    AppSettings settings = translating,
    List<Character> characters = const [],
    List<GlossaryPack> packs = const [],
    PipelineLayout layout = PipelineLayout.screenStandard,
  }) => buildPipelineGraph(
    settings: settings,
    characters: characters,
    packs: packs,
    layout: layout,
    scheme: PipelineScheme.screen,
  );

  bool joined(PipelineGraph graph, PipelinePort from, PipelinePort to) =>
      graph.links.contains(PipelineLink(from, to));

  /// The line of text, stop by stop, from the screen.
  List<String> lineOf(PipelineGraph graph) {
    final next = {
      for (final link in graph.links)
        if (link.signal == PipelineSignal.text) link.from.nodeId: link.to.nodeId,
    };
    final line = [screen];
    for (var after = next[screen]; after != null; after = next[after]) {
      line.add(after);
    }
    return line;
  }

  group('the stages', () {
    test('are the screen, the translator, the voice, the mix, the output and the game', () {
      final graph = drawn();

      expect(graph.scheme, PipelineScheme.screen);
      expect(
        [for (final node in graph.nodes) node.id],
        [source, detection, screen, translation, voice, mix, output],
      );
      expect(graph.node(PipelineNodeIds.recognition), isNull, reason: 'nothing here is heard');
      expect(graph.nodes.every((node) => node.scheme == PipelineScheme.screen), isTrue);
    });

    test('stand where nobody moved them in two lines from the left edge', () {
      final graph = drawn();

      for (final MapEntry(key: id, value: at) in PipelineLayout.screenPositions.entries) {
        expect(graph.node(id)?.position, at, reason: id);
      }
    });

    test('keep a stage the player moved where it was left', () {
      final graph = drawn(
        layout: PipelineLayout.screenStandard.withPosition(detection, const GraphPoint(9, 9)),
      );

      expect(graph.node(detection)?.position, const GraphPoint(9, 9));
    });

    test('fall back to the screen\'s places, not Эфир\'s, for what the layout omits', () {
      final graph = drawn(layout: const PipelineLayout());

      expect(graph.node(voice)?.position, PipelineLayout.screenPositions[voice]);
      expect(graph.node(source)?.position, PipelineLayout.screenPositions[source]);
    });

    test('are always routed: the screen is read whatever else is drawn', () {
      final graph = drawn(settings: const AppSettings(captureRouted: false));

      expect(graph.routed, isTrue);
      expect(graph.node(screen)?.unrouted, isFalse);
      expect(joined(graph, screenText, intoTranslator), isTrue);
    });
  });

  group('the line of text', () {
    test('runs from the screen through the translator into the voice', () {
      final graph = drawn();

      expect(graph.translates, isTrue);
      expect(lineOf(graph), [screen, translation, voice]);
      expect(graph.node(translation)?.unrouted, isFalse);
    });

    test('passes the translator by for text read in the dubbing language', () {
      final graph = drawn(settings: readAsIs);

      expect(graph.translates, isFalse);
      expect(lineOf(graph), [screen, voice]);
      expect(graph.node(translation)?.unrouted, isTrue, reason: 'it stands aside');
    });

    test('passes it by for English read into English as well', () {
      final graph = drawn(settings: const AppSettings(targetLanguage: 'en'));

      expect(lineOf(graph), [screen, voice]);
    });

    test('says nothing of Эфир\'s language: whisper is not on this scheme', () {
      // Dubbing into Russian whatever the game speaks, and English text off
      // the screen: the screen's translator stands in the line.
      final graph = drawn(settings: const AppSettings(sourceLanguage: 'ru'));

      expect(graph.translates, isTrue);
    });

    test('runs through the packs drawn on it, from the screen on', () {
      final packs = [
        GlossaryPack(id: 'lines', name: 'Реплики', active: true),
        GlossaryPack(id: 'names', name: 'Имена', active: true),
      ];
      final layout = PipelineLayout.screenStandard
          .withGlossary('lines', feed: GlossaryFeed.recognition)
          .withGlossary('names', feed: GlossaryFeed.translation);

      final graph = drawn(packs: packs, layout: layout);

      expect(lineOf(graph), [
        screen,
        PipelineNodeIds.glossary(1),
        translation,
        PipelineNodeIds.glossary(2),
        voice,
      ]);
      expect(graph.ofKind(PipelineNodeKind.glossary).every((node) => !node.unrouted), isTrue);
    });

    test('puts a pack drawn nowhere yet over the screen\'s translator', () {
      final graph = drawn(
        packs: [GlossaryPack(id: 'lines', name: 'Реплики')],
        layout: PipelineLayout.screenStandard.withGlossary('lines'),
      );

      expect(
        graph.node(PipelineNodeIds.glossary(1))?.position,
        PipelineLayout.glossaryPlace(0, scheme: PipelineScheme.screen),
      );
      expect(
        PipelineLayout.glossaryPlace(0, scheme: PipelineScheme.screen),
        isNot(PipelineLayout.glossaryPlace(0)),
        reason: 'the screen\'s translator stands a stage further left than Эфир\'s',
      );
    });

    test('lets a pack before the translator apply its words when nothing is translated', () {
      final packs = [GlossaryPack(id: 'lines', name: 'Реплики', active: true)];
      final layout = PipelineLayout.screenStandard
          .withGlossary('lines', feed: GlossaryFeed.recognition)
          .withGlossary('lines', feed: GlossaryFeed.translation);

      final graph = drawn(settings: readAsIs, packs: packs, layout: layout);

      expect(graph.node(PipelineNodeIds.glossary(1))?.unrouted, isFalse);
      expect(graph.node(PipelineNodeIds.glossary(2))?.unrouted, isTrue);
      expect(layout.glossaryReach(translates: false), {
        'lines': {GlossaryKind.word},
      });
    });
  });

  group('the voices behind the screen', () {
    test('are not listened for until the detection is switched on', () {
      final graph = drawn();

      expect(joined(graph, gameAudio, intoDetection), isFalse);
      expect(joined(graph, speaker, intoVoiceSpeaker), isFalse);
      expect(graph.node(source)?.unrouted, isTrue, reason: 'the game\'s sound goes nowhere');
      expect(graph.node(detection)?.unrouted, isTrue);
      expect(graph.node(detection)?.active, isFalse);
    });

    test('run from the game through the detection into the voice once it is', () {
      final graph = drawn(settings: const AppSettings(screenVoices: true));

      expect(joined(graph, gameAudio, intoDetection), isTrue);
      expect(joined(graph, speaker, intoVoiceSpeaker), isTrue);
      expect(graph.node(source)?.unrouted, isFalse);
      expect(graph.node(detection)?.unrouted, isFalse);
      expect(graph.node(detection)?.active, isTrue);
    });

    test('reach a voice socket Эфир\'s voice has not got', () {
      final screenVoice = drawn().node(voice)!;
      final liveVoice = buildPipelineGraph(
        settings: const AppSettings(),
        characters: const [],
      ).node(voice)!;

      expect(screenVoice.sockets, contains(PipelineSocket.voiceSpeaker));
      expect(liveVoice.sockets, isNot(contains(PipelineSocket.voiceSpeaker)));
      expect(PipelineSocket.voiceSpeaker.drawnOn(PipelineScheme.live), isFalse);
      expect(PipelineSocket.voiceIn.drawnOn(PipelineScheme.screen), isTrue);
    });

    test('tell apart the same node on the two schemes', () {
      final screenMix = drawn().node(mix)!;
      final liveMix = buildPipelineGraph(settings: const AppSettings(), characters: const []).node(
        mix,
      )!;

      expect(screenMix.position == liveMix.position, isFalse);
      expect(
        screenMix,
        isNot(
          PipelineNode(
            id: mix,
            kind: PipelineNodeKind.mix,
            position: screenMix.position,
          ),
        ),
        reason: 'the scheme is part of what the node draws',
      );
    });
  });

  group('the cast', () {
    const guard = Character(id: 'guard', name: 'Стражник', vector: [0.2]);

    test('is read from the voice and sent on to the mix, as on Эфир', () {
      final graph = drawn(
        characters: [guard],
        layout: PipelineLayout.screenStandard.withCharacter('guard'),
      );
      final card = PipelineNodeIds.character('guard');

      expect(
        graph.linkInto(PipelinePort(card, PipelineSocket.characterIn))?.from,
        const PipelinePort(voice, PipelineSocket.voiceCast),
      );
      expect(
        joined(
          graph,
          PipelinePort(card, PipelineSocket.characterVoice),
          const PipelinePort(mix, PipelineSocket.mixCast),
        ),
        isTrue,
      );
      expect(graph.node(card)?.scheme, PipelineScheme.screen);
    });
  });

  group('what a link would change', () {
    test('the voices listened for, by either line of the detection', () {
      final graph = drawn();

      expect(
        proposeConnection(graph, gameAudio, intoDetection),
        isA<VoicesConnection>().having((connection) => connection.heard, 'heard', isTrue),
      );
      expect(
        proposeConnection(graph, intoVoiceSpeaker, speaker),
        isA<VoicesConnection>().having((connection) => connection.heard, 'heard', isTrue),
        reason: 'drawn backwards, from the voice',
      );
    });

    test('nothing, where the voices are listened for already', () {
      final graph = drawn(settings: const AppSettings(screenVoices: true));

      expect(proposeConnection(graph, gameAudio, intoDetection), isA<UnchangedConnection>());
    });

    test('is refused between who is speaking and anything but the voice', () {
      final graph = drawn();

      expect(
        proposeConnection(graph, speaker, intoVoice),
        isA<RefusedConnection>().having(
          (connection) => connection.reason,
          'reason',
          ConnectionRefusal.signal,
        ),
      );
      expect(
        proposeConnection(graph, gameAudio, const PipelinePort(mix, PipelineSocket.mixIn)),
        isA<RefusedConnection>().having(
          (connection) => connection.reason,
          'reason',
          ConnectionRefusal.unsupported,
        ),
      );
    });

    test('the translator stepped over, when the screen is taken to the voice', () {
      expect(
        proposeConnection(drawn(), screenText, intoVoice),
        isA<TranslationConnection>().having((connection) => connection.routed, 'routed', isFalse),
      );
    });

    test('the translator back in the line, drawn at either end of it', () {
      final graph = drawn(settings: readAsIs);

      for (final (from, to) in [(screenText, intoTranslator), (translated, intoVoice)]) {
        expect(
          proposeConnection(graph, from, to),
          isA<TranslationConnection>().having((connection) => connection.routed, 'routed', isTrue),
          reason: '$from -> $to',
        );
      }
    });

    test('a pack put in the line right after the screen', () {
      final layout = PipelineLayout.screenStandard.withGlossary('lines');
      final graph = drawn(
        packs: [GlossaryPack(id: 'lines', name: 'Реплики')],
        layout: layout,
      );
      final pack = PipelineNodeIds.glossary(1);

      final connection = proposeConnection(
        graph,
        screenText,
        PipelinePort(pack, PipelineSocket.glossaryIn),
      );

      expect(
        connection,
        isA<GlossaryLineConnection>().having((connection) => connection.edits, 'edits', [
          LineMove(pack, anchor: screen, after: true),
        ]),
      );
      expect(
        layout.withLine((connection as GlossaryLineConnection).edits, translates: true).glossaries,
        [GlossaryPlacement(nodeId: pack, packId: 'lines', feed: GlossaryFeed.recognition)],
        reason: 'right after the screen is before the translator',
      );
    });

    test('the packs a line from the screen passes over taken out of it', () {
      final layout = PipelineLayout.screenStandard.withGlossary(
        'lines',
        feed: GlossaryFeed.recognition,
      );
      final graph = drawn(
        packs: [GlossaryPack(id: 'lines', name: 'Реплики', active: true)],
        layout: layout,
      );

      expect(
        proposeConnection(graph, screenText, intoTranslator),
        isA<GlossaryLineConnection>().having((connection) => connection.edits, 'edits', [
          LineRemove({PipelineNodeIds.glossary(1)}),
        ]),
      );
    });
  });

  group('cutting a link', () {
    test('stops listening for the voices, by either line of the detection', () {
      for (final link in [
        const PipelineLink(gameAudio, intoDetection),
        const PipelineLink(speaker, intoVoiceSpeaker),
      ]) {
        expect(
          proposeDisconnect(link),
          isA<VoicesConnection>().having((connection) => connection.heard, 'heard', isFalse),
          reason: '$link',
        );
      }
    });

    test('still takes Эфир\'s way in apart, which leaves the same socket', () {
      expect(
        proposeDisconnect(
          const PipelineLink(
            gameAudio,
            PipelinePort(PipelineNodeIds.recognition, PipelineSocket.speechIn),
          ),
        ),
        isA<RouteConnection>().having((connection) => connection.routed, 'routed', isFalse),
      );
    });

    test('reads the text as it is, by either half of the translator\'s line', () {
      for (final link in [
        const PipelineLink(screenText, intoTranslator),
        const PipelineLink(translated, intoVoice),
      ]) {
        expect(
          proposeDisconnect(link),
          isA<TranslationConnection>().having((connection) => connection.routed, 'routed', isFalse),
        );
      }
    });

    test('puts the translator back rather than leave the voice with nothing to read', () {
      expect(
        proposeDisconnect(const PipelineLink(screenText, intoVoice)),
        isA<TranslationConnection>().having((connection) => connection.routed, 'routed', isTrue),
      );
    });
  });

  group('the arrangement on disk', () {
    test('falls back to the screen\'s own when the file says nothing', () {
      expect(
        PipelineLayout.fromJson(null, scheme: PipelineScheme.screen),
        same(PipelineLayout.screenStandard),
      );
      expect(
        PipelineLayout.fromJson(const {
          'nodes': <String, Object?>{},
        }, scheme: PipelineScheme.screen).positions,
        PipelineLayout.screenPositions,
      );
      expect(PipelineLayout.fromJson(null), same(PipelineLayout.standard));
      expect(PipelineLayout.standardOf(PipelineScheme.live), same(PipelineLayout.standard));
    });
  });

  group('a kept scheme', () {
    const kept = SavedPipeline(
      id: 's1',
      name: 'Субтитры',
      scheme: PipelineScheme.screen,
      captureRouted: false,
      layout: PipelineLayout.screenStandard,
    );

    test('comes back as the Screen page\'s, with its route', () {
      final read = SavedPipeline.fromJson(kept.toJson())!;

      expect(read.scheme, PipelineScheme.screen);
      expect(read.captureRouted, isFalse);
      expect(read.layout.positions, PipelineLayout.screenPositions);
      expect(read.copyWith(name: 'Другая').scheme, PipelineScheme.screen);
    });

    test('is Эфир\'s when it says nothing, as every scheme kept before was', () {
      const live = SavedPipeline(id: 's2', name: 'Таверна');

      expect(live.toJson().containsKey('scheme'), isFalse, reason: 'the file stays as it was');
      expect(SavedPipeline.fromJson(live.toJson())!.scheme, PipelineScheme.live);
      expect(
        SavedPipeline.fromJson(const {'id': 's3', 'scheme': 'somewhere else'})!.scheme,
        PipelineScheme.live,
        reason: 'a canvas a later version adds is read as Эфир\'s',
      );
    });

    test('is read onto its own canvas\'s shelf and no other', () {
      final library = const PipelineLibrary(
        pipelines: [
          kept,
          SavedPipeline(id: 's2', name: 'Таверна'),
        ],
      ).toJson();

      expect(
        PipelineLibrary.fromJson(library, scheme: PipelineScheme.screen).pipelines.map((p) => p.id),
        ['s1'],
      );
      expect(PipelineLibrary.fromJson(library).pipelines.map((p) => p.id), ['s2']);
      expect(PipelineLibrary.pipelinesOf(kept.toJson(), PipelineScheme.live), isEmpty);
    });
  });

  group('which sessions a scheme speaks for', () {
    test('the Screen page\'s, the screen session alone', () {
      expect(PipelineScheme.screen.feeds(PipelineSession.screen), isTrue);
      for (final session in PipelineSession.values.where((s) => s != PipelineSession.screen)) {
        expect(PipelineScheme.screen.feeds(session), isFalse, reason: session.name);
        expect(PipelineScheme.live.feeds(session), isTrue, reason: session.name);
      }
      expect(PipelineScheme.live.feeds(PipelineSession.screen), isFalse);
    });

    test('none while the engine rests', () {
      expect(PipelineScheme.live.feeds(null), isFalse);
      expect(PipelineScheme.screen.feeds(null), isFalse);
    });

    test('each with the stage its line starts at', () {
      expect(PipelineScheme.live.lineHead, PipelineNodeIds.recognition);
      expect(PipelineScheme.screen.lineHead, screen);
      expect(PipelineScheme.live.stages, PipelineNodeIds.stages);
    });
  });

  group('the settings', () {
    test('translate the screen only for English text into another language', () {
      expect(translating.screenTranslates, isTrue);
      expect(readAsIs.screenTranslates, isFalse);
      expect(const AppSettings(targetLanguage: 'en').screenTranslates, isFalse);
      expect(
        const AppSettings(screenLanguage: 'de').screenTranslates,
        isTrue,
        reason: 'a language nothing reads is read as English',
      );
    });
  });
}
