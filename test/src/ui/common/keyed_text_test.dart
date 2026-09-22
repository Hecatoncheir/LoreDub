// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/hotkey.dart';
import 'package:lore_dub/src/ui/common/key_marks.dart';
import 'package:lore_dub/src/ui/common/keyed_text.dart';

import '../../../support/key_finders.dart';

/// The keys an interface string names, drawn as keys.
void main() {
  /// The runs as text -- `[Ctrl|S]` for keys -- since a record holding a
  /// list tells it from an equal one by identity.
  List<String> read(String text) => [
    for (final run in keyedRuns(text)) run.keys.isEmpty ? run.words : '[${run.keys.join('|')}]',
  ];

  group('the marks', () {
    test('cut a string into what is said and what is pressed', () {
      expect(read('Нажмите сочетание… (<kbd>Esc</kbd> — отмена)'), [
        'Нажмите сочетание… (',
        '[Esc]',
        ' — отмена)',
      ]);
    });

    test('read a combination the settings wrote as the keys it holds', () {
      const hotkey = Hotkey(keyCode: 0xBB, label: '+', control: true, alt: true);

      expect(
        read('<kbd>${hotkey.display}</kbd>'),
        ['[Ctrl|Alt|+]'],
        reason: 'a key that is itself a plus is still a key',
      );
    });

    test('leave a string with no key in it as it is, and pass an empty mark by', () {
      expect(read('Горячие клавиши'), ['Горячие клавиши']);
      expect(read('a <kbd></kbd>b'), ['a ', 'b']);
      expect(read(''), isEmpty);
    });
  });

  testWidgets('draws each key as a key, and the words around them as words', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: KeyedText('Удерживайте <kbd>Ctrl + Alt + S</kbd> и обведите текст')),
      ),
    );

    expect(keysHeld('Ctrl + Alt + S'), findsOneWidget);
    expect([keyCap('Ctrl'), keyCap('Alt'), keyCap('S')], everyElement(findsOneWidget));
    expect(find.textContaining('Удерживайте'), findsOneWidget);
    expect(find.textContaining('<kbd>'), findsNothing, reason: 'the marks are never shown');
  });
}
