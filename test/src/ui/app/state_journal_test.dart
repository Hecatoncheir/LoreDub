// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/ui/app/state_journal.dart';

/// A bloc small enough that the journal is the only thing under test.
class _Counter extends Bloc<String, int> {
  _Counter() : super(0) {
    on<String>((event, emit) => emit(state + 1));
  }
}

class _Switch extends Cubit<bool> {
  _Switch() : super(false);

  void flip() => emit(!state);
}

void main() {
  test('writes the event a bloc took and the state it reached', () async {
    final journal = StateJournal(echo: false);
    Bloc.observer = journal;
    addTearDown(() => Bloc.observer = StateJournal(echo: false));
    final counter = _Counter();
    addTearDown(counter.close);

    counter.add('step');
    await Future<void>.delayed(Duration.zero);

    expect(journal.lines, ['_Counter <- step', '_Counter -> int']);
  });

  test('a cubit has no events, so only what it reached is written', () async {
    final journal = StateJournal(echo: false);
    Bloc.observer = journal;
    addTearDown(() => Bloc.observer = StateJournal(echo: false));
    final toggle = _Switch();
    addTearDown(toggle.close);

    toggle.flip();

    expect(journal.lines, ['_Switch -> bool']);
  });

  test('keeps the last lines rather than the whole session', () async {
    // A drag on the canvas is a state per frame; a journal without a
    // ceiling would be every frame the session ever drew.
    final journal = StateJournal(kept: 3, echo: false);
    Bloc.observer = journal;
    addTearDown(() => Bloc.observer = StateJournal(echo: false));
    final toggle = _Switch();
    addTearDown(toggle.close);

    for (var flip = 0; flip < 10; flip++) {
      toggle.flip();
    }

    expect(journal.lines, hasLength(3));
  });
}
