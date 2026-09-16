// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/glossary.dart';

/// The built-in pack's id. Stable, so the pack is recognised on a machine
/// that already has it rather than added a second time.
const builtInGlossaryPackId = 'loredub-en-ru';

/// The pack LoreDub brings with it: the English a game shouts, where the
/// translator is measurably wrong about it.
///
/// Every line here was put through the same Marian the pipeline runs and
/// kept only where the answer was wrong -- "Weapons free." came back as
/// «Оружие бесплатно.», "Tango down." as «Танго вниз.», "Objective updated."
/// as «Объектив обновлен.». What the model already says well is not here:
/// "Grenade!", "Take cover!", "Reloading!", "Hold your fire!", "It's a
/// trap!" and thirty others answered correctly and need no entry, and an
/// entry that never fires is a line of noise in the player's glossary.
///
/// Phrases only, and that is a measurement too. A [GlossaryKind.name] reaches
/// a word the translator left in Latin script, and over sixteen names in two
/// frames each it left none: every one came back rendered -- Megaton as
/// «Мегатон», Rapture as «Восторг», Goodneighbor as «Добрососедство» -- so
/// name entries written here would never fire. A [GlossaryKind.word] is
/// matched on the dubbing language and replaces that word wherever it stands,
/// so a general pack of them would reach lines that have nothing to do with a
/// game. Both belong in a pack made for one game, where the player knows
/// which words are theirs.
Glossary builtInGlossary() => Glossary(
  entries: _entries,
  packs: [
    GlossaryPack(
      id: builtInGlossaryPackId,
      name: 'LoreDub · English → Русский',
      entryKeys: [for (final entry in _entries) entry.packKey],
    ),
  ],
);

GlossaryEntry _phrase(String source, String reading) =>
    GlossaryEntry(kind: GlossaryKind.phrase, source: source, reading: reading);

/// Each line is followed by what the translator answered instead.
final _entries = <GlossaryEntry>[
  // Combat calls. The model reads them word by word and loses the meaning.
  _phrase('Fire in the hole!', 'Ложись!'), // Огонь в дыру!
  _phrase('Frag out!', 'Граната!'), // Отвали!
  _phrase('Covering fire!', 'Прикрываю!'), // Прикрывающий огонь!
  _phrase('Suppressing fire!', 'Огонь на подавление!'), // Подавляющий огонь!
  _phrase('Weapons free.', 'Огонь по готовности.'), // Оружие бесплатно.
  _phrase('Light em up.', 'Открыть огонь.'), // Зажги их.
  _phrase('Lock and load.', 'К бою.'), // Заблокировать и загрузить.
  _phrase('Man down!', 'У нас раненый!'), // Человек ранен!
  _phrase('Hostiles inbound.', 'Противник приближается.'), // Враждебные люди.
  _phrase('Flanking!', 'Заходят с фланга!'), // Фланкировать!
  _phrase('Tango down.', 'Цель уничтожена.'), // Танго вниз.
  _phrase('Target down.', 'Цель уничтожена.'), // Цель вниз.
  _phrase('Watch your six.', 'Прикрой спину.'), // Осторожно, шестеро.
  _phrase('Eyes up.', 'Смотри в оба.'), // Глаза вверх.
  _phrase('Stay frosty.', 'Будь начеку.'), // Не сдавайся.
  _phrase('Out of ammo!', 'Патроны кончились!'), // У нас нет патронов!
  // Stealth and alarm.
  _phrase("They're onto us.", 'Нас засекли.'), // Они нас ловят.
  _phrase('Stay low.', 'Пригнись.'), // Не шевелитесь.
  _phrase('Who goes there?', 'Кто идёт?'), // Кто туда ходит?
  _phrase("I'm seeing things.", 'Мне мерещится.'), // Я вижу вещи.
  // Whisper hears a line with no speaker and the model guesses a woman; a
  // line that may be said to anyone should not.
  _phrase('Did you hear that?', 'Ты это слышал?'), // Ты слышала?
  // Quest and interface lines, where a word of the trade is read as an
  // ordinary one.
  _phrase('Objective updated.', 'Задание обновлено.'), // Объектив обновлен.
  _phrase('New objective.', 'Новое задание.'), // Новая цель.
  _phrase('Journal updated.', 'Журнал обновлён.'), // Журнал обновляется.
  _phrase('Quest complete.', 'Задание выполнено.'), // Квест завершен.
  _phrase('Level up!', 'Новый уровень!'), // Уровень выше!
  _phrase('You are over-encumbered.', 'Вы перегружены.'), // Ты слишком обременен.
  _phrase('I need a medkit.', 'Нужна аптечка.'), // Мне нужно лекарство.
  _phrase('My health is low.', 'У меня мало здоровья.'), // Здоровье у меня низкое.
  // Partings and greetings a fantasy game is full of.
  _phrase('Safe travels.', 'Счастливого пути.'), // Безопасные путешествия.
  _phrase('May the road rise to meet you.', 'Доброго пути.'),
  _phrase('Well met, traveler.', 'Приветствую, путник.'),
  // Driving, and two idioms that survive nothing word by word.
  _phrase('Floor it!', 'Газуй!'), // На пол!
  _phrase('Hang in there.', 'Держись.'), // Держись там.
  _phrase('That was close.', 'Чуть не попались.'), // Это было близко.
];
