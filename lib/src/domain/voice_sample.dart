// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// What a voice says when the player asks to hear it.
library;

/// A line for [name]'s voice to speak, in [language].
///
/// Not in the language of the interface: the speech model reads the language
/// it was packaged for, and a Russian voice handed an English line says it
/// letter by letter. The interface may be in either.
String voiceSample(String language, String name) {
  final called = name.trim();
  return switch (language) {
    'ru' =>
      called.isEmpty
          ? 'Здравствуйте. Так я буду звучать в игре.'
          : 'Здравствуйте. Меня зовут $called, и так я буду звучать в игре.',
    _ =>
      called.isEmpty
          ? 'Hello. This is how I will sound in the game.'
          : 'Hello. My name is $called, and this is how I will sound in the game.',
  };
}
