// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// The scheme: the canvas, its nodes, its links and its shelf.

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/capture_sources.dart';
import 'package:lore_dub/src/domain/character.dart';
import 'package:lore_dub/src/domain/game_process.dart';
import 'package:lore_dub/src/domain/pipeline_graph.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart' show PipelineStatus;
import 'package:lore_dub/src/domain/saved_pipeline.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/navigation_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/pipeline_graph_bloc.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/session_bloc.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/voice_capture_bloc.dart';
import 'package:lore_dub/src/ui/graph/canvas/pipeline_canvas.dart';
import 'package:lore_dub/src/ui/graph/inspector/pipeline_inspector.dart';

import '../../../support/dashboard_harness.dart';
import '../../../support/mock_blocs.dart';
import '../../../support/staged_dashboard.dart';

void main() {
  // What `captureAny` stands in with before anything is captured.
  setUpAll(registerEventFallbacks);

  testWidgets('keeps a scheme under the name the dialog is given', (tester) async {
    // Through the running application rather than staged cubits: what broke
    // here was the dialog's own field being let go of while the dialog was
    // still fading, and a fade needs a screen that really has one.
    await pumpLoreDub(tester, const Size(1400, 920));
    await tester.tap(find.text('Схема'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byIcon(Icons.bookmark_add_outlined));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Название схемы'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Вечер в таверне');
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить схему'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull, reason: 'the dialog took nothing down with it');
    // The shelf keeps it, folded away until its heading is pressed.
    expect(find.textContaining('СОХРАНЁННЫЕ СХЕМЫ'), findsOneWidget);
    await tester.tap(find.textContaining('СОХРАНЁННЫЕ СХЕМЫ'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Вечер в таверне'), findsOneWidget);
  });

  group('the pipeline graph', () {
    const guard = Character(id: 'guard', name: 'Стражник', vector: [0.2, 0.4], seconds: 2.5);
    const smith = Character(id: 'smith', name: 'Кузнец', vector: [0.1, 0.9], seconds: 3.5);

    /// The canvas with the two cards on it, drawn from settings the test
    /// stages rather than from a disk it does not have.
    Future<StagedDashboard> pumpGraph(
      WidgetTester tester, {
      AppSettings settings = const AppSettings(),
      List<Character> characters = const [guard, smith],
      List<String> placed = const ['guard'],
      List<SavedPipeline> shelf = const [],
    }) async {
      final cubits = stage(
        buildCubits(),
        section: DashboardSection.live,
        liveView: LiveView.scheme,
        settings: settings,
        models: catalogue(),
      );
      cubits.cast.seed(CharacterLibrary(characters: characters));
      cubits.stageScheme(layout: PipelineLayout.drawing(placed), shelf: shelf);
      await pumpDashboard(tester, cubits, const Size(1500, 950));
      await tester.pump();
      return cubits;
    }

    testWidgets('draws the stages of the pipeline as nodes', (tester) async {
      await pumpGraph(tester);

      expect(find.text('01  /  ПУТЬ СИГНАЛА'), findsOneWidget);
      expect(find.text('Оригинальный поток'), findsOneWidget);
      expect(find.text('Whisper'), findsOneWidget);
      expect(find.text('Перевод'), findsOneWidget);
      expect(find.text('Сведение'), findsOneWidget);
      expect(find.text('Поток'), findsOneWidget);
      expect(find.text('Стражник'), findsOneWidget);
      expect(
        find.text('Кузнец'),
        findsNothing,
        reason: 'only the cards put on the canvas are drawn',
      );
      expect(find.byType(ChoiceChip), findsNothing, reason: 'one route needs no presets');
    });

    testWidgets('asks for no game where the whole output is captured', (tester) async {
      await pumpGraph(
        tester,
        settings: const AppSettings(audioCaptureSource: AudioCaptureSource.system),
      );

      expect(find.text('Игра не выбрана'), findsNothing);
      expect(find.text('Устройство по умолчанию'), findsWidgets);
    });

    testWidgets('holds the game while a card is being recorded', (tester) async {
      final cubits = await pumpGraph(tester);

      await tester.tap(find.text('Оригинальный поток').first);
      await tester.pumpAndSettle();

      final picker = find.byType(DropdownMenu<GameProcess>);
      expect(tester.widget<DropdownMenu<GameProcess>>(picker).enabled, isTrue);

      // The node is a second window onto the same choice, and the characters
      // screen is recording through the game it names.
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      cubits.voices.emit(const VoiceCaptureState(status: PipelineStatus.listening));
      await tester.pump();
      await tester.pump();

      expect(
        tester.widget<DropdownMenu<GameProcess>>(picker).enabled,
        isFalse,
        reason: 'the recording listens to the game this would change',
      );
    });

    testWidgets('sets the volume and the pace in the same ranges the settings do', (tester) async {
      final cubits = await pumpGraph(tester);

      // The node sits at the far edge of the canvas, where the panel that
      // opens would cover it; selected directly instead of by a tap.
      cubits.graph.add(const PipelineNodeSelected(PipelineNodeIds.output));
      await tester.pumpAndSettle();

      final volume = tester.widget<Slider>(find.byKey(const ValueKey('graphOriginalVolume')));
      expect(volume.min, AppSettings.audibleDuck);
      expect(volume.max, AppSettings.loudestDuck);
      expect(volume.divisions, AppSettings.duckDivisions);
      // Material draws no value over a thumb that carries no label, and the
      // number under the pointer is what the hand watches while it drags.
      expect(volume.label, isNotNull);
      expect(find.text('Приглушать только под перевод'), findsOneWidget);

      cubits.graph.add(const PipelineNodeSelected(PipelineNodeIds.voice));
      await tester.pumpAndSettle();

      final pace = tester.widget<Slider>(find.byKey(const ValueKey('graphTtsSpeed')));
      expect(pace.min, AppSettings.slowestSpeech);
      expect(pace.max, AppSettings.fastestSpeech);
      expect(pace.divisions, AppSettings.speechDivisions);
      expect(pace.label, isNotNull);
      expect(find.text('Ускорять озвучку, когда реплики ждут очереди'), findsOneWidget);
    });

    testWidgets('opens what a node is set to when it is clicked', (tester) async {
      await pumpGraph(tester);

      await tester.tap(find.text('Перевод').first);
      await tester.pumpAndSettle();

      expect(find.text('ВЫБРАНО'), findsOneWidget);
      // Both ends of the stage, and the one that is settled says so: whisper
      // hands English over whatever the game speaks.
      expect(find.text('С какого языка'), findsOneWidget);
      expect(find.text('На какой язык'), findsOneWidget);
      expect(find.textContaining('Whisper отдаёт английский текст'), findsOneWidget);
    });

    testWidgets('slides the panel in from under the frame of the canvas', (tester) async {
      // The panel stood beside the card the scheme is drawn in, and came in
      // from a place to the right of that card which the screen has not got.
      // It is inside the card now, and the card clips: halfway in it is cut
      // off at the frame rather than lying over the page beyond it. It is
      // also moving by then — a panel opening on a canvas with none on it
      // used to wait out the half of the run kept for the one it replaces,
      // and that wait read as a click that had missed the node.
      await pumpGraph(tester);

      await tester.tap(find.text('Перевод').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      final frame = find
          .ancestor(of: find.byType(PipelineCanvas), matching: find.byType(Card))
          .first;
      expect(
        find.descendant(of: frame, matching: find.byType(PipelineInspector)),
        findsOneWidget,
        reason: 'the panel is drawn inside the card that clips the canvas',
      );
      final edge = tester.getRect(frame).right;
      final onItsWay = tester.getRect(find.byType(PipelineInspector));
      expect(onItsWay.left, lessThan(edge), reason: 'part of the panel is out');
      expect(onItsWay.right, greaterThan(edge), reason: 'and the rest is under the frame');

      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(PipelineInspector)).right,
        moreOrLessEquals(edge, epsilon: 0.01),
        reason: 'it comes to rest against that same edge',
      );
    });

    testWidgets('never offers a card the voice of one it already reads', (tester) async {
      // The canvas refuses that line, but the card's own panel used to list
      // the whole cast, so the two could be set to read each other there.
      final cubits = await pumpGraph(tester);
      cubits.cast.seed(
        const CharacterLibrary(
          characters: [
            Character(id: 'guard', name: 'Стражник', vector: [0.2, 0.4]),
            Character(id: 'smith', name: 'Кузнец', vector: [0.1, 0.9], voicedBy: 'guard'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Стражник').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('graph-reader-guard-null')));
      await tester.pumpAndSettle();

      expect(find.text('Своим голосом'), findsWidgets);
      expect(
        find.text('Кузнец'),
        findsNothing,
        reason: 'the smith is already read by the guard',
      );
    });

    testWidgets('says what each line parts with when it is cut', (tester) async {
      // One tooltip served all three, worded for the substitution alone: the
      // line out of a card into the mix offered to «give the voice back»,
      // which that card was never lent.
      await pumpGraph(
        tester,
        characters: const [
          Character(id: 'guard', name: 'Стражник', vector: [0.2], voicedBy: 'smith'),
          smith,
        ],
        placed: const ['guard', 'smith'],
      );

      expect(find.byTooltip('Отсоединить оригинальный поток'), findsOneWidget);
      expect(find.byTooltip('Убрать персонажей из сведения'), findsOneWidget);
      expect(
        find.byTooltip('Вернуть свой голос'),
        findsOneWidget,
        reason: 'only the line that lends a part offers to take it back',
      );
    });

    testWidgets('rests and wakes the session from the graph itself', (tester) async {
      // The cast is rewired here; walking to Live to pause first would be a
      // walk for nothing.
      final cubits = await pumpGraph(tester);
      expect(find.byKey(const ValueKey('graphPause')), findsNothing);

      cubits.stageSession(const SessionState(status: PipelineStatus.listening));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('graphPause')));
      await tester.pumpAndSettle();

      expect(cubits.pipeline.state.status, PipelineStatus.paused);

      await tester.tap(find.byKey(const ValueKey('graphPause')));
      await tester.pumpAndSettle();

      expect(cubits.pipeline.state.status, PipelineStatus.listening);

      await tester.tap(find.byKey(const ValueKey('graphStop')));
      await tester.pumpAndSettle();

      expect(cubits.pipeline.state.status, PipelineStatus.idle);
      expect(find.byKey(const ValueKey('graphPause')), findsNothing);
    });

    testWidgets('says the lender is read by the card that takes the part', (tester) async {
      // «Стражник» is spoken by «Кузнец»: the line runs out of the card
      // whose part it is and into the card that will speak it, so it is the
      // first that is read in another's voice, not the second.
      await pumpGraph(
        tester,
        characters: const [
          Character(id: 'guard', name: 'Стражник', vector: [0.2], voicedBy: 'smith'),
          smith,
        ],
        placed: const ['guard', 'smith'],
      );

      expect(find.text('Голосом «Кузнец»'), findsOneWidget);
      expect(
        find.text('Своим голосом'),
        findsOneWidget,
        reason: 'the card lending its voice speaks for itself as well',
      );
    });

    testWidgets('renames a character from the node it is drawn as', (tester) async {
      final cubits = await pumpGraph(tester);

      cubits.graph.add(PipelineNodeSelected(PipelineNodeIds.character('guard')));
      await tester.pumpAndSettle();

      final field = find.descendant(
        of: find.byType(PipelineInspector),
        matching: find.byKey(const ValueKey('graph-name-guard')),
      );
      expect(field, findsOneWidget);

      await tester.enterText(field, 'Часовой');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(
        cubits.cast.cast.firstWhere((value) => value.id == 'guard').name,
        'Часовой',
      );
      // The node is drawn from the cast, so its own header follows at once.
      expect(find.text('Часовой'), findsWidgets);
      expect(find.text('Стражник'), findsNothing);
    });

    testWidgets('gives the panel buttons room for what they are called', (tester) async {
      final cubits = await pumpGraph(tester);

      cubits.graph.add(PipelineNodeSelected(PipelineNodeIds.character('guard')));
      await tester.pumpAndSettle();

      // Side by side in a panel 320 wide, both labels were cut — one of them
      // across the middle of a word.
      for (final label in ['Персонажи', 'Убрать со схемы']) {
        final text = find.descendant(
          of: find.byType(PipelineInspector),
          matching: find.text(label),
        );
        expect(text, findsOneWidget, reason: label);
        expect(
          tester.getSize(text).height,
          lessThan(24),
          reason: '$label is written on one line',
        );
        expect(
          tester.getSize(text).width,
          greaterThan(60),
          reason: '$label is not squeezed to nothing',
        );
      }
    });

    testWidgets('offers the cast to read a character with', (tester) async {
      final cubits = await pumpGraph(tester);

      await tester.tap(find.text('Стражник').first);
      await tester.pumpAndSettle();

      expect(find.text('Озвучивать как'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Кузнец').last);
      await tester.pumpAndSettle();

      expect(cubits.cast.cast.first.voicedBy, 'smith');
      expect(find.text('Кузнец'), findsWidgets, reason: 'the reader joins the canvas');
    });

    testWidgets('picks the game in a field that filters as it is typed', (tester) async {
      final cubits = await pumpGraph(tester);
      cubits.sourcesRepository.seed(
        CaptureSources(
          processes: [
            for (var index = 0; index < 30; index++)
              GameProcess(
                pid: 1000 + index,
                name: 'conhost.exe',
                path: 'C:/conhost$index.exe',
              ),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Оригинальный поток').first);
      await tester.pumpAndSettle();

      final picker = tester.widget<DropdownMenu<GameProcess>>(
        find.byType(DropdownMenu<GameProcess>),
      );
      expect(picker.enableFilter, isTrue);
      expect(picker.requestFocusOnTap, isTrue);
      expect(
        picker.dropdownMenuEntries.first.label,
        contains('PID 1000'),
        reason: 'two processes of one name are told apart by their pid',
      );
      expect(find.byTooltip('Обновить список процессов'), findsOneWidget);

      final field = find.descendant(
        of: find.byType(DropdownMenu<GameProcess>),
        matching: find.byType(TextField),
      );
      await tester.tap(field);
      await tester.pumpAndSettle();

      final entry = find.text('conhost.exe  ·  PID 1000').hitTestable();
      expect(entry, findsOneWidget);
      expect(
        tester.getTopLeft(entry).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(field).dy),
        reason: 'the list must not slide up over the field it is typed into',
      );
    });

    testWidgets('chooses a second node with shift held', (tester) async {
      final cubits = await pumpGraph(tester);

      await tester.tap(find.text('Whisper'));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.text('Перевод'));
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

      expect(cubits.graph.state.chosen, {
        PipelineNodeIds.recognition,
        PipelineNodeIds.translation,
      });
      // Two nodes have no settings between them, so the panel stays shut.
      expect(cubits.graph.state.selected, isNull);
      expect(find.byType(PipelineInspector), findsNothing);
    });

    testWidgets('draws a band with control held and chooses what it covers', (tester) async {
      final cubits = await pumpGraph(tester);
      final source = tester.getCenter(find.text('Оригинальный поток'));
      final canvas = tester.getRect(find.byType(PipelineCanvas));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      // From an empty corner of the canvas across the first card: a band, not
      // a pan, which is what the modifier is for.
      final gesture = await tester.startGesture(canvas.topLeft + const Offset(6, 6));
      await gesture.moveTo(source + const Offset(20, 20));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(cubits.graph.state.chosen, contains(PipelineNodeIds.source));
      expect(
        cubits.graph.state.layout.view.x,
        PipelineGraphState(layout: cubits.graph.state.layout).layout.view.x,
        reason: 'the canvas stayed where it was',
      );
    });

    testWidgets('carries every chosen node with the one being dragged', (tester) async {
      final cubits = await pumpGraph(tester);
      await tester.tap(find.text('Whisper'));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.text('Перевод'));
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Whisper')),
        kind: PointerDeviceKind.mouse,
      );
      // Past the slop first, so what is measured is drag and nothing else.
      await gesture.moveBy(const Offset(8, 8));
      await tester.pump();
      final was = {
        for (final id in [PipelineNodeIds.recognition, PipelineNodeIds.translation])
          id: cubits.graph.state.graph.node(id)!.position,
      };

      await gesture.moveBy(const Offset(60, 20));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final zoom = cubits.graph.state.layout.view.zoom;
      for (final id in was.keys) {
        final moved = cubits.graph.state.graph.node(id)!.position;
        expect(moved.x - was[id]!.x, closeTo(60 / zoom, 1));
        expect(moved.y - was[id]!.y, closeTo(20 / zoom, 1));
      }
    });

    testWidgets('puts a card on the canvas from the toolbar', (tester) async {
      final cubits = await pumpGraph(tester, placed: const []);

      expect(find.text('Стражник'), findsNothing);
      await tester.tap(find.byIcon(Icons.person_add_alt_rounded));
      // The menu is pushed in the microtask after the tap, so its own frames
      // start only once the first pump has run.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Стражник'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(cubits.graph.state.layout.characters, ['guard']);
      expect(find.text('Стражник'), findsWidgets);
    });

    testWidgets('draws a card again from the toolbar, and says how many are out', (tester) async {
      final cubits = await pumpGraph(tester);

      await tester.tap(find.byIcon(Icons.person_add_alt_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The card already on the canvas is offered again rather than left
      // out: a copy beside the part it takes over keeps the line short.
      expect(find.widgetWithText(PopupMenuItem<String>, 'Стражник'), findsOneWidget);
      expect(find.text('\u00d71'), findsOneWidget, reason: 'one of it is drawn');

      await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Стражник'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(cubits.graph.state.layout.characters, ['guard', 'guard']);
      expect(find.text('Стражник'), findsWidgets);
    });

    testWidgets('offers to write the canvas over a scheme it has kept', (tester) async {
      // A scheme kept when the canvas held nothing, which the canvas has
      // moved on from since. What choosing the item does is the bloc's, and
      // is pinned there; this is that the shelf offers it at all.
      await pumpGraph(
        tester,
        shelf: const [SavedPipeline(id: 's1', name: 'Вечер в таверне')],
      );
      await tester.tap(find.textContaining('СОХРАНЁННЫЕ СХЕМЫ'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Вечер в таверне'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Перезаписать'), findsOneWidget);
      expect(find.text('Переименовать'), findsOneWidget);
    });

    testWidgets('takes a card out of the voices the game speaks', (tester) async {
      final cubits = await pumpGraph(tester);
      final counted = cubits.graph.state.graph.linkInto(
        PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.characterIn),
      )!;

      expect(
        find.byTooltip('Не слышать этого персонажа в игре'),
        findsOneWidget,
        reason: 'the dashed line comes apart by the badge on it',
      );

      cubits.graph.add(PipelineLinkCut(counted));
      await tester.pump();
      await tester.pump();

      expect(
        cubits.graph.state.graph.linkInto(
          PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.characterIn),
        ),
        isNull,
      );
      expect(find.text('Стражник'), findsWidgets, reason: 'the card stays where it was put');
    });
  });
}
