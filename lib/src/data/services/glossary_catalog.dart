// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/glossary.dart';

/// The built-in packs' ids. Stable, so a pack is recognised on a machine that
/// already has it rather than added a second time.
const builtInGlossaryPackId = 'loredub-en-ru';
const builtInQuotesPackId = 'loredub-quotes';

/// The packs LoreDub brings with it.
///
/// Every line in both was put through the same Marian the pipeline runs and
/// kept only where the answer was wrong -- "Weapons free." came back as
/// «Оружие бесплатно.», "We're taking fire!" as «Мы стреляем!», "Requiescat
/// in pace." as «Требуем в темпе.». What the model already says well is not
/// here: "Grenade!", "Take cover!", "Roger that.", "Get over here!",
/// "Objection!" and some seventy others answered correctly and need no
/// entry, and an entry that never changes a line is noise in the player's
/// glossary.
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
  entries: [..._general, ..._quotes],
  packs: [
    GlossaryPack(
      id: builtInGlossaryPackId,
      name: 'LoreDub · English → Русский',
      entryKeys: [for (final entry in _general) entry.packKey],
    ),
    GlossaryPack(
      id: builtInQuotesPackId,
      name: 'LoreDub · Крылатые фразы',
      entryKeys: [for (final entry in _quotes) entry.packKey],
    ),
  ],
);

GlossaryEntry _phrase(String source, String reading) =>
    GlossaryEntry(kind: GlossaryKind.phrase, source: source, reading: reading);

/// What a game shouts, where the translator reads it word by word and loses
/// the meaning. Each line is followed by what the model answered instead.
final _general = <GlossaryEntry>[
  // Combat calls.
  _phrase('Fire in the hole!', 'Ложись!'), // Огонь в дыру!
  _phrase('Frag out!', 'Граната!'), // Отвали!
  _phrase('Covering fire!', 'Прикрываю!'), // Прикрывающий огонь!
  _phrase('Suppressing fire!', 'Огонь на подавление!'), // Подавляющий огонь!
  _phrase('Weapons free.', 'Огонь по готовности.'), // Оружие бесплатно.
  _phrase('Weapons hot.', 'Оружие к бою.'), // Оружие горячее.
  _phrase("Light 'em up.", 'Открыть огонь.'), // Зажги их.
  _phrase('Lock and load.', 'К бою.'), // Заблокировать и загрузить.
  _phrase('Man down!', 'У нас раненый!'), // Человек ранен!
  _phrase('Hostiles inbound.', 'Противник приближается.'), // Враждебные люди.
  _phrase('Flanking!', 'Заходят с фланга!'), // Фланкировать!
  _phrase('Tango down.', 'Цель уничтожена.'), // Танго вниз.
  _phrase('Target down.', 'Цель уничтожена.'), // Цель вниз.
  _phrase('Watch your six.', 'Прикрой спину.'), // Осторожно, шестеро.
  _phrase('On your six.', 'У тебя за спиной.'), // На шестерых.
  _phrase('Eyes up.', 'Смотри в оба.'), // Глаза вверх.
  _phrase('Eyes on target.', 'Цель вижу.'), // Взгляд на цель.
  _phrase('Stay frosty.', 'Будь начеку.'), // Не сдавайся.
  _phrase('Out of ammo!', 'Патроны кончились!'), // У нас нет патронов!
  // Radio and room clearing, where a word of the trade is read as a plain
  // one -- and twice the meaning comes back inside out.
  _phrase("We're taking fire!", 'По нам стреляют!'), // Мы стреляем!
  _phrase('Your forces are under attack.', 'Ваши войска атакованы.'), // Ваши силы атакуют.
  _phrase('Breaching!', 'Врываемся!'), // Нарушение!
  _phrase('Stack up.', 'К двери.'), // Складывайся.
  _phrase('Smoke out!', 'Ставлю дым!'), // Выкури!
  _phrase('Rally on me.', 'Все ко мне.'), // Собраться на меня.
  _phrase('Check your corners.', 'Проверь углы.'), // Проверьте свои углы.
  _phrase('Requesting extraction.', 'Запрашиваю эвакуацию.'), // Требую извлечения.
  _phrase('The LZ is hot.', 'Зона высадки под огнём.'), // ЖК горячий.
  _phrase('Objective secured.', 'Цель захвачена.'), // Цель обеспечена.
  _phrase('Back off.', 'Отходи.'), // Отвали.
  // Multiplayer callouts.
  _phrase("He's low!", 'У него мало здоровья!'), // Он низковат!
  _phrase('Need heals!', 'Нужно лечение!'), // Нужны исцеления!
  _phrase("They're pushing!", 'Они наступают!'), // Они толкают!
  _phrase('Push mid.', 'Идём в центр.'), // Нажимаем посередине.
  // Stealth and alarm.
  _phrase("They're onto us.", 'Нас засекли.'), // Они нас ловят.
  _phrase("We've been made.", 'Нас раскрыли.'), // Нас сделали.
  _phrase('Stay low.', 'Пригнись.'), // Не шевелитесь.
  _phrase('Who goes there?', 'Кто идёт?'), // Кто туда ходит?
  _phrase('Halt, who goes there?', 'Стой, кто идёт?'), // Стой, кто туда ходит?
  _phrase('Sound the alarm!', 'Бей тревогу!'), // Включите будильник!
  _phrase('The alarm is going off!', 'Сработала тревога!'), // Будильник срабатывает!
  _phrase('Take him out quietly.', 'Убери его тихо.'), // Выведите его тихо.
  _phrase("I'm seeing things.", 'Мне мерещится.'), // Я вижу вещи.
  _phrase('Keep your light on.', 'Не выключай фонарь.'), // Не загорайтесь.
  // Whisper hears a line with no speaker and the model guesses a woman; a
  // line that may be said to anyone should not.
  _phrase('Did you hear that?', 'Ты это слышал?'), // Ты слышала?
  // Quest and interface lines.
  _phrase('Objective updated.', 'Задание обновлено.'), // Объектив обновлен.
  _phrase('New objective.', 'Новое задание.'), // Новая цель.
  _phrase('Journal updated.', 'Журнал обновлён.'), // Журнал обновляется.
  _phrase('Quest complete.', 'Задание выполнено.'), // Квест завершен.
  _phrase('Level up!', 'Новый уровень!'), // Уровень выше!
  _phrase('You are over-encumbered.', 'Вы перегружены.'), // Ты слишком обременен.
  _phrase('I need a medkit.', 'Нужна аптечка.'), // Мне нужно лекарство.
  _phrase('My health is low.', 'У меня мало здоровья.'), // Здоровье у меня низкое.
  // Fantasy and the words a guard says.
  _phrase('Shields up!', 'Поднять щиты!'), // Щиты вверх!
  _phrase('You have my bow.', 'Мой лук с тобой.'), // У тебя мой поклон.
  _phrase("I'll take my leave.", 'Позвольте откланяться.'), // Я возьму отпуск.
  _phrase('State your business.', 'С чем пожаловали?'), // Покажите свой бизнес.
  // Chases and driving.
  _phrase("We've got a tail.", 'За нами хвост.'), // У нас есть хвост.
  _phrase('Lose them!', 'Оторвись от них!'), // Проиграй их!
  _phrase('Punch it!', 'Жми!'), // Врежь!
  _phrase('Floor it!', 'Газуй!'), // На пол!
  // Partings and greetings a fantasy game is full of.
  _phrase('Safe travels.', 'Счастливого пути.'), // Безопасные путешествия.
  _phrase('May the road rise to meet you.', 'Доброго пути.'),
  _phrase('Well met, traveler.', 'Приветствую, путник.'),
  // Idioms, which survive nothing word by word.
  _phrase('Piece of cake.', 'Проще простого.'), // Кусок пирога.
  _phrase('No dice.', 'Не выйдет.'), // Без костей.
  _phrase('Beats me.', 'Понятия не имею.'), // Поймал меня.
  _phrase('Long story short.', 'Короче говоря.'), // Короткая история.
  _phrase('Keep your eyes peeled.', 'Гляди в оба.'), // Держи глаза чистыми.
  _phrase('Hold your horses.', 'Не торопись.'), // Держите лошадей.
  _phrase('Break a leg.', 'Ни пуха ни пера.'), // Сломать ногу.
  _phrase('Speak of the devil.', 'Лёгок на помине.'), // Поговорим о дьяволе.
  _phrase('Heads or tails?', 'Орёл или решка?'), // Орел или хвост?
  _phrase('Get a load of this guy.', 'Ты только глянь на него.'), // Принеси ему кучу.
  _phrase('Hang in there.', 'Держись.'), // Держись там.
  _phrase('That was close.', 'Чуть не попались.'), // Это было близко.
];

/// The lines a player knows by heart, in the wording they know them in.
///
/// A quotation is the one place where being literally right is not enough:
/// the line is remembered as it was localized, and a fresh translation of it
/// lands wrong however correct it is. Kept, again, only where the model
/// differs -- "War. War never changes." it already answers word for word, so
/// it is not here.
final _quotes = <GlossaryEntry>[
  _phrase('Would you kindly?', 'Будьте любезны.'), // Не могли бы вы быть любезны?
  _phrase('A man chooses, a slave obeys.', 'Человек выбирает, раб подчиняется.'),
  _phrase('Praise the sun!', 'Восславим солнце!'), // Хвалите солнце!
  _phrase('You died.', 'Вы погибли.'), // Ты умер.
  _phrase('Endure. In enduring, grow strong.', 'Терпи. В терпении обретёшь силу.'),
  _phrase('Stay awhile and listen.', 'Останься ненадолго и послушай.'),
  _phrase(
    'I used to be an adventurer like you, then I took an arrow in the knee.',
    'Я тоже когда-то был искателем приключений, пока мне не прострелили колено.',
  ),
  _phrase("Hey, you. You're finally awake.", 'Эй, ты. Наконец-то очнулся.'),
  _phrase('Do you get to the Cloud District very often?', 'Часто бываешь в Облачном квартале?'),
  _phrase('Nothing is true, everything is permitted.', 'Ничто не истинно, всё дозволено.'),
  _phrase('Requiescat in pace.', 'Покойся с миром.'), // Требуем в темпе.
  _phrase('Rise and shine, Mister Freeman.', 'Вставайте, мистер Фримен. Вставайте и пойте.'),
  _phrase(
    'The right man in the wrong place can make all the difference in the world.',
    'Нужный человек в ненужном месте способен изменить весь мир.',
  ),
  _phrase('Kept you waiting, huh?', 'Заждался, а?'), // Ты ждал, да?
  _phrase('Another settlement needs our help.', 'Другому поселению нужна наша помощь.'),
  _phrase('The Vault Dweller has returned.', 'Обитатель Убежища вернулся.'), // Домой Домовладельцы
  _phrase('Finish him!', 'Добей его!'), // Прикончи его!
  _phrase("It's super effective!", 'Это очень эффективно!'), // Это супер эффективно!
  _phrase('Hey! Listen!', 'Эй! Слушай!'), // Эй! Слушайте!
  _phrase('You must construct additional pylons.', 'Требуются дополнительные пилоны.'),
  _phrase('My life for Aiur!', 'Моя жизнь за Айур!'), // Моя жизнь для Айура!
  _phrase('Work work.', 'Работаю, работаю.'), // Работа.
  _phrase('Something need doing?', 'Что-нибудь нужно?'), // Что-то нужно сделать?
  _phrase('Stand and deliver.', 'Кошелёк или жизнь.'), // Встаньте и доставьте.
  _phrase('Do a barrel roll!', 'Сделай бочку!'), // Сделай бочкообразный бросок!
  _phrase(
    'What is a man? A miserable little pile of secrets.',
    'Что есть человек? Жалкая горстка секретов!',
  ),
  _phrase('All your base are belong to us.', 'Вся ваша база принадлежат нам.'),
];
