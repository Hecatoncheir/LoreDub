// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/l10n/app_localizations.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/pipeline_graph.dart';
import 'package:lore_dub/src/domain/compute_device.dart';
import 'package:lore_dub/src/domain/model_selection.dart';
import 'package:lore_dub/src/ui/graph/canvas/link_cut_badge.dart';
import 'package:lore_dub/src/ui/graph/canvas/node_card.dart';
import 'package:lore_dub/src/ui/graph/canvas/node_inputs.dart';
import 'package:lore_dub/src/ui/graph/canvas/node_layer.dart';
import 'package:lore_dub/src/ui/graph/canvas/node_layer_actions.dart';
import 'package:lore_dub/src/ui/graph/canvas/node_layer_cache.dart';
import 'package:lore_dub/src/ui/graph/canvas/pipeline_facts.dart';
import 'package:lore_dub/src/ui/graph/node_faces.dart';
import 'package:lore_dub/src/ui/theme.dart';

/// The canvas keeps what it drew: a badge whose line has not moved comes
/// back as the same widget on the next frame. That is what makes a drag of
/// two dozen cards cheap, and it is also the one way a change of theme
/// could be missed -- a widget the parent hands back unchanged is not
/// rebuilt for the parent's sake.
///
/// It is rebuilt for its own: the colours are read inside `build`, so the
/// badge depends on the theme and the framework rebuilds it when the theme
/// changes, cache or no cache. This is what says so.
void main() {
  final graph = buildPipelineGraph(settings: const AppSettings(), characters: const []);

  /// Nothing happens in this test, so every one of them does nothing.
  final actions = NodeLayerActions(
    onTap: (_) {},
    onGrab: (_, _) {},
    onDrag: (_, _) {},
    onDrop: () {},
    onRemove: (_) {},
    onSwitch: (_, _) {},
    onLinkStart: (_, _) {},
    onLinkToggle: (_) {},
    onLinkDrag: (_) {},
    onLinkEnd: () {},
  );

  /// The roles with one colour moved, so a badge drawn under the old ones
  /// is told from a badge drawn under these at a glance.
  final repainted = LoreDubColors.light.copyWith(raised: const Color(0xFF00FF00));

  Color badgeColour(WidgetTester tester) => tester
      .widget<Material>(
        find.descendant(of: find.byType(LinkCutBadge), matching: find.byType(Material)).first,
      )
      .color!;

  /// Whatever [draw] asks the cache for, under a theme the test can move.
  /// [draw] is called on every build, so it is the cache that decides
  /// whether a frame gets the same widget or a new one -- exactly as on the
  /// canvas.
  Future<void Function()> pumpCached(
    WidgetTester tester,
    List<Widget> Function() draw,
  ) async {
    var colors = LoreDubColors.light;
    late StateSetter repaint;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          repaint = setState;
          return MaterialApp(
            theme: AppTheme.light
                .copyWith(extensions: [colors])
                .withNodeFaces(
                  NodeFaces.from(colors),
                ),
            locale: const Locale('ru'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Builder(builder: (context) => Stack(children: draw())),
          );
        },
      ),
    );
    // `MaterialApp` lerps one theme into the next, so the new colours are
    // only fully there once that has run.
    return () async => repaint(() => colors = repainted);
  }

  testWidgets('a badge kept from the last frame still follows the theme', (tester) async {
    final cache = BadgeCache();
    final drawn = <LinkCutBadge>[];

    final repaint = await pumpCached(tester, () {
      final badges = cache.badgesFor(graph, (_) {});
      drawn.add(badges.first);
      return [badges.first];
    });

    expect(badgeColour(tester), LoreDubColors.light.raised);

    repaint();
    await tester.pumpAndSettle();

    // The cache did hand back the same widget -- otherwise this proves
    // nothing about the cache, only that a fresh widget reads the theme.
    expect(identical(drawn.first, drawn.last), isTrue, reason: 'the badge was rebuilt, not kept');
    expect(badgeColour(tester), repainted.raised);
  });

  testWidgets('a card kept from the last frame still follows the faces', (tester) async {
    final cache = NodeLayerCache();
    final drawn = <NodeLayer>[];
    final inputs = <NodeInputs>[
      (
        node: graph.node(PipelineNodeIds.mix)!,
        selected: false,
        zoom: 1,
        facts: const PipelineFacts(
          settings: AppSettings(),
          selection: ModelSelection(models: [], settings: AppSettings()),
        ),
        availability: const ComputeAvailability(),
        filled: 0,
        offered: 0,
        pulling: null,
        over: null,
      ),
    ];

    final repaint = await pumpCached(tester, () {
      final layers = cache.layersFor(inputs, actions);
      drawn.add(layers.first);
      return [layers.first];
    });

    Color cardColour() => tester
        .widget<DecoratedBox>(
          find.descendant(of: find.byType(NodeCard), matching: find.byType(DecoratedBox)).first,
        )
        .decoration
        .let();

    expect(cardColour(), NodeFaces.light.forNode(graph.node(PipelineNodeIds.mix)!).body);

    repaint();
    await tester.pumpAndSettle();

    expect(identical(drawn.first, drawn.last), isTrue, reason: 'the card was rebuilt, not kept');
    expect(cardColour(), NodeFaces.from(repainted).forNode(graph.node(PipelineNodeIds.mix)!).body);
  });
}

extension on Decoration {
  Color let() => (this as BoxDecoration).color!;
}
