// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'LoreDub';

  @override
  String get navGroupDubbing => 'DUBBING';

  @override
  String get navGroupSetup => 'SETUP';

  @override
  String get navLive => 'Live';

  @override
  String get headerLive => 'LIVE VOICE';

  @override
  String get headerScreen => 'SCREEN TEXT';

  @override
  String get headerCharacters => 'CHARACTER CAST';

  @override
  String get headerPipeline => 'SIGNAL PATH';

  @override
  String get headerModels => 'MODEL BANK';

  @override
  String get headerSettings => 'SIGNAL SETUP';

  @override
  String get areaGameInput => 'GAME INPUT';

  @override
  String get areaTranscript => 'LIVE TRANSCRIPT';

  @override
  String get areaSceneVoices => 'SCENE VOICES';

  @override
  String get areaScreenCapture => 'SCREEN CAPTURE';

  @override
  String get areaSubtitleFrame => 'SUBTITLE FRAME';

  @override
  String get areaSubtitles => 'SUBTITLES';

  @override
  String get areaSelectedText => 'SELECTED TEXT';

  @override
  String get areaVoiceRecording => 'VOICE RECORDING';

  @override
  String get areaCast => 'CAST';

  @override
  String get areaPacks => 'PACKS';

  @override
  String sizeMegabytes(String value) {
    return '$value MB';
  }

  @override
  String sizeGigabytes(String value) {
    return '$value GB';
  }

  @override
  String get navSnapshot => 'Screen';

  @override
  String get headerGlossary => 'GAME GLOSSARY';

  @override
  String get transcriptCorrect => 'Write into the glossary';

  @override
  String get transcriptCorrectTitle => 'How to say this line';

  @override
  String get transcriptCorrectNote =>
      'It goes into the Glossary as a phrase and is said this way whenever the game says this line -- in any game, and from the next line rather than the next start.';

  @override
  String get navGlossary => 'Glossary';

  @override
  String get titleGlossary => 'What the dubbing cannot know';

  @override
  String get glossaryExport => 'Export';

  @override
  String get glossaryImport => 'Import';

  @override
  String failureGlossaryExportFailed(String detail) {
    return 'The glossary could not be exported: $detail';
  }

  @override
  String failureGlossaryImportFailed(String detail) {
    return 'The file $detail holds no glossary';
  }

  @override
  String get glossaryPhrases => 'PHRASES';

  @override
  String get glossaryPhrasesNote =>
      'A whole line with your own translation: the answer comes from here and the model is not asked at all. This is where idioms belong -- the model is not wrong about \"Fire in the hole!\" so much as ignorant of the game. The match is on the whole sentence, and neither case nor spacing counts.';

  @override
  String get glossaryPhraseSource => 'The line in English';

  @override
  String get glossaryPhraseReading => 'How to say it';

  @override
  String get glossaryNames => 'NAMES';

  @override
  String get glossaryNamesNote =>
      'A name the translator left in Latin script -- and that is the only place an entry is used. Measured, the model transliterates and correctly declines the names it does render (\"The people of Megaton\" comes back as \"Жители Мегатона\"), so a substitution over the whole line would break the grammar it found. Without an entry, Latin left behind is simply written out: Rapture becomes \"Раптур\".';

  @override
  String get glossaryNameSource => 'The name in English';

  @override
  String get glossaryNameReading => 'How to say it';

  @override
  String get glossaryWords => 'WORDS';

  @override
  String get glossaryWordsNote =>
      'A word of a line already translated, replaced by yours -- the one entry matched on the dubbing language rather than on English. The model is usually steady about a name and declines it correctly: over eight lines measured, Vault came back as «Убежище» seven times and «Хранилище» once, and nothing else here reaches that eighth line. The whole word is replaced and nothing less: carrying an ending over to another word was measured producing «Восторге» and «Восторгя», so an entry passes a declined form by rather than invent one that does not exist. Do not write a short everyday word here: it will turn up where you did not expect it.';

  @override
  String get glossaryWordSource => 'As it is said now';

  @override
  String get glossaryWordReading => 'How to say it';

  @override
  String get glossaryEmpty => 'Nothing here yet.';

  @override
  String get glossaryPacks => 'PACKS';

  @override
  String get glossaryPacksNote =>
      'A pack is a way of reading the glossary rather than a place entries are moved to: an entry stays in its list whether or not a pack names it. With no pack switched on, the dubbing is checked against everything written down. With one or more on, it is checked against those alone -- so a pack made for one game does not drag another game\'s names along. Several may be on at once and what they hold adds together.';

  @override
  String get glossaryPacksEmpty =>
      'No packs yet. Make one and drag entries into it by the handle on the left -- a set collected for one game is then handed on as a single file.';

  @override
  String get glossaryPackDropHint => 'Drag entries from the lists above here.';

  @override
  String get glossaryPackDragHint => 'Drag the entry into a pack';

  @override
  String get glossaryPackImport => 'Load a pack';

  @override
  String get glossaryPackActive => 'Active';

  @override
  String get glossaryPackActiveHint =>
      'While any pack is switched on, the dubbing is checked against the switched-on packs alone';

  @override
  String glossaryPackCount(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString entries',
      one: '$countString entry',
      zero: 'empty',
    );
    return '$_temp0';
  }

  @override
  String get glossaryAdd => 'Add';

  @override
  String get glossaryRemove => 'Remove';

  @override
  String get navCharacters => 'Characters';

  @override
  String get titleCharacters => 'Character voices';

  @override
  String get charactersNote =>
      'A card remembers a character\'s voice: walk up to them in the game, press Record the voice and let them talk. Characters are shared by every game, and in Live their lines are read in the voice given to them. A voice can also be built from recordings you already have: drop them on the card.';

  @override
  String get voicesOnTheGraph =>
      'Which character reads whose lines can be set on the Graph screen.';

  @override
  String get charactersHowTo =>
      'Start the recording session, choose the game process, and record the voices one by one.';

  @override
  String get charactersNeedsConverter =>
      'The voice converter is needed: download it in the Original voice section of the Models screen.';

  @override
  String get charactersSessionStart => 'Start recording';

  @override
  String get charactersSessionStop => 'Stop recording';

  @override
  String get charactersAdd => 'Add';

  @override
  String get charactersImport => 'Import';

  @override
  String get charactersExport => 'Export';

  @override
  String get charactersExportHint => 'Save the card to a file';

  @override
  String get charactersExportAll => 'Export all';

  @override
  String get charactersNewName => 'New character';

  @override
  String get charactersNameLabel => 'Character name';

  @override
  String get charactersEmpty => 'No characters yet. Press Add and record a voice.';

  @override
  String get charactersRecord => 'Record the voice';

  @override
  String get charactersPlayClip => 'Play the recording';

  @override
  String get charactersStopSound => 'Stop the playback';

  @override
  String get charactersPreviewVoice => 'Hear the dubbing voice';

  @override
  String get charactersPreviewPlain =>
      'Hear the dubbing voice. The character’s timbre is not carried over: turn on Original voice on the Models screen, or a plain synthesized voice reads them';

  @override
  String get charactersPreviewLoading => 'Getting the voice ready…';

  @override
  String get charactersPreviewNeedsModel =>
      'The speech model is missing: fetch it on the Models screen';

  @override
  String get charactersPlayingClip => 'Sounding…';

  @override
  String get charactersNoClip =>
      'No recording: the card came from a file, which carries only the fingerprint';

  @override
  String get charactersRecordStop => 'Stop';

  @override
  String get charactersRecording => 'Recording — let the character talk';

  @override
  String charactersHeard(String seconds) {
    return '$seconds s recorded';
  }

  @override
  String get charactersNoVoice => 'No voice recorded yet';

  @override
  String get charactersBuilding => 'Measuring the voice from the files…';

  @override
  String charactersBuiltFrom(int files, String agreement) {
    return 'Built from $files recordings · agreement $agreement';
  }

  @override
  String get charactersBuiltFromOne => 'Built from one recording';

  @override
  String get charactersBuiltApart => 'The recordings sound like more than one voice';

  @override
  String charactersBuiltSkipped(int files) {
    return 'No voice in: $files';
  }

  @override
  String charactersVoiceKept(String seconds, String gender) {
    return 'Voice recorded · $seconds s · $gender';
  }

  @override
  String get charactersGenderUnknown => 'gender undecided';

  @override
  String get charactersDelete => 'Delete the character';

  @override
  String get charactersVoicedByHint => 'Read in another character’s voice';

  @override
  String get charactersOwnVoice => 'Their own voice';

  @override
  String get charactersDeleteTitle => 'Delete the character?';

  @override
  String charactersDeleteMessage(String name) {
    return 'The card $name and the voice recorded for it will be deleted.';
  }

  @override
  String get charactersDeleteConfirm => 'Delete';

  @override
  String get charactersDeleteCancel => 'Cancel';

  @override
  String charactersImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count characters added',
      one: '$count character added',
      zero: 'No characters added',
    );
    return '$_temp0';
  }

  @override
  String charactersInPacks(String packs) {
    return 'In packs: $packs';
  }

  @override
  String get packsAdd => 'New pack';

  @override
  String get packsNewName => 'New pack';

  @override
  String get packsNameLabel => 'Pack name';

  @override
  String get packsEmpty =>
      'No packs yet. Make one and drag cards into it — a cast collected that way is handed on as a single file.';

  @override
  String get packsDropHint => 'Drag character cards here.';

  @override
  String get packsExportHint => 'Save the pack to a file';

  @override
  String get packsDelete => 'Delete the pack';

  @override
  String get packsRemoveMember => 'Take out of the pack';

  @override
  String packsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count characters',
      one: '$count character',
      zero: 'empty',
    );
    return '$_temp0';
  }

  @override
  String get packsDeleteTitle => 'Delete the pack?';

  @override
  String packsDeleteMessage(String name) {
    return 'The pack “$name” will be deleted. Its characters stay in the cast.';
  }

  @override
  String packsImported(int packs, int characters) {
    String _temp0 = intl.Intl.pluralLogic(
      packs,
      locale: localeName,
      other: '$packs packs',
      one: '$packs pack',
    );
    String _temp1 = intl.Intl.pluralLogic(
      characters,
      locale: localeName,
      other: '$characters characters',
      one: '$characters character',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get navModels => 'Models';

  @override
  String get navSettings => 'Settings';

  @override
  String get titleLive => 'Game dubbing';

  @override
  String get titleSnapshot => 'Screen translation';

  @override
  String get titleModels => 'Local models';

  @override
  String get titleSettings => 'Signal setup';

  @override
  String get statusIdle => 'Stopped';

  @override
  String get statusStarting => 'Starting…';

  @override
  String get statusListening => 'Listening';

  @override
  String get statusSnapshotReady => 'Reading the screen';

  @override
  String get statusPaused => 'Paused';

  @override
  String get statusStopping => 'Stopping…';

  @override
  String get statusError => 'Error';

  @override
  String get routeNeededTitle => 'The way in is not drawn';

  @override
  String get routeNeededAction => 'To the graph';

  @override
  String get modelsNeededTitle => 'The first run needs models';

  @override
  String get modelsNeededNote => 'They are downloaded separately and are not part of the setup.';

  @override
  String get modelsNeededAction => 'Open models';

  @override
  String get startChecklistTitle => 'Before the first start';

  @override
  String get startStepGame => 'Choose the game in the process list';

  @override
  String get processLabel => 'Game process';

  @override
  String get processHint => 'Type a process name';

  @override
  String processEntry(String name, int pid) {
    return '$name  ·  PID $pid';
  }

  @override
  String get captureProcessNote => 'Only the selected process is captured';

  @override
  String get captureSystemNote => 'The whole default output is captured, except LoreDub itself';

  @override
  String get settingsAudioSource => 'Audio source';

  @override
  String get sourceSystem => 'System audio';

  @override
  String get sourceProcess => 'Game audio';

  @override
  String get refreshProcesses => 'Refresh the process list';

  @override
  String get targetLanguageLabel => 'Dubbing language';

  @override
  String get translationFromLabel => 'From';

  @override
  String get translationToLabel => 'Into';

  @override
  String get translationFromWhisper =>
      'Whisper hands over English whatever the game speaks, so the translation always starts from it.';

  @override
  String languageWithoutModels(String language) {
    return '$language · not downloaded';
  }

  @override
  String get sourceLanguageLabel => 'Original language';

  @override
  String get detectLanguage => 'Detect language';

  @override
  String detectedLanguage(String language) {
    return 'Detected: $language';
  }

  @override
  String get startDubbing => 'Start dubbing';

  @override
  String get stopDubbing => 'Stop';

  @override
  String get stopHint => 'Stop dubbing altogether';

  @override
  String get pauseDubbing => 'Pause';

  @override
  String get pauseHint => 'Pause: the models stay loaded and the game plays at full volume';

  @override
  String get resumeDubbing => 'Resume';

  @override
  String snapshotHowTo(String hotkey) {
    return 'Hold $hotkey, draw a frame around the text over the game and let go — LoreDub reads it, translates it and voices it.';
  }

  @override
  String get screenHowTo =>
      'While the session runs the subtitles in the frame are read and voiced by themselves -- only what a line gained is spoken.';

  @override
  String get silenceWhileReading => 'Silence the game';

  @override
  String get silenceWhileReadingNote =>
      'The game\'s sound means nothing here -- the text comes off the screen -- so it may be turned off altogether, rather than speaking a line at the same moment as the dubbing. Off, the game is turned down as it is on Live.';

  @override
  String get screenPickGame => 'Choose the game whose screen to read';

  @override
  String get snapshotNoHotkey => 'No snapshot key is bound.';

  @override
  String get snapshotOpenSettings => 'Bind one in Settings';

  @override
  String snapshotNote(String language) {
    return 'Only the translator and the voice ($language) are loaded, no speech recognition. The selected game\'s window is read while it is in front -- run the game windowed or borderless.';
  }

  @override
  String get screenSourceWindow => 'Game window';

  @override
  String get screenSourceScreen => 'Whole screen';

  @override
  String screenWholeNote(String language) {
    return 'Only the translator and the voice ($language) are loaded, no speech recognition. Everything on the screen is read, whichever window is in front — which is what a game without an ordinary window needs. No game has to be named.';
  }

  @override
  String get snapshotStart => 'Start';

  @override
  String get snapshotStop => 'Stop';

  @override
  String get snapshotReading => 'Reading and translating the snippet…';

  @override
  String get snapshotMissed => 'No text found in the selected area';

  @override
  String get snapshotInLive => 'Live dubbing is running — the snapshot key works there too';

  @override
  String get snapshotEmpty => 'Selected text will appear here';

  @override
  String get snapshotClearTooltip => 'Remove the snippets from the list';

  @override
  String get settingsHotkeys => 'Hotkeys';

  @override
  String get hotkeysNote =>
      'They work while Live or Screen runs, even with the game on screen; the combination then does not reach the game. The snapshot and frame keys are held down while the area is drawn with the mouse.';

  @override
  String get hotkeyPause => 'Pause';

  @override
  String get hotkeyResume => 'Resume';

  @override
  String get hotkeySnapshot => 'Select an area';

  @override
  String get hotkeyFrame => 'Subtitle frame';

  @override
  String frameHowTo(String hotkey) {
    return 'The frame can be redrawn during the game: hold $hotkey, draw around the place the subtitles are written and let go — the selection disappears and the reading goes on inside the new frame.';
  }

  @override
  String get frameMissed => 'The selection missed the game window — the frame is where it was';

  @override
  String get hotkeyUnset => 'Not set';

  @override
  String get hotkeyListening => 'Press a combination… (Esc cancels)';

  @override
  String get hotkeyClear => 'Remove the combination';

  @override
  String get hotkeyNeedsModifier =>
      'Add Ctrl, Alt or Win: a key on its own would stop reaching the game';

  @override
  String get hotkeyUnsupported => 'This key cannot be bound';

  @override
  String hotkeyDuplicate(String action) {
    return 'This combination is already bound to $action';
  }

  @override
  String failureHotkeyTaken(String action) {
    return 'Another program already holds the combination for $action — bind a different one in Settings.';
  }

  @override
  String failureGlossarySaveFailed(String detail) {
    return 'The glossary could not be saved: $detail';
  }

  @override
  String failureCharactersSaveFailed(String detail) {
    return 'The characters could not be saved: $detail';
  }

  @override
  String failureCharactersExportFailed(String detail) {
    return 'The card could not be exported: $detail';
  }

  @override
  String failureCharactersImportFailed(String detail) {
    return 'The file $detail holds no LoreDub characters.';
  }

  @override
  String get sceneVoices => 'Voices of the scene';

  @override
  String get sceneVoicesNote => 'Who LoreDub has heard this session, and whose voice reads them.';

  @override
  String get sceneVoicesEmpty =>
      'Nobody has spoken yet. Press “Place the voices” — or start dubbing, and they gather by themselves.';

  @override
  String get sceneVoicesListen => 'Place the voices';

  @override
  String get sceneVoicesListenStop => 'Stop';

  @override
  String get sceneVoicesListening =>
      'Listening to the game. Voices appear here as characters speak; nothing is dubbed meanwhile.';

  @override
  String sceneVoiceHeardFor(String seconds) {
    return 'Heard for $seconds s';
  }

  @override
  String get sceneVoicesNeedsConverter =>
      'Voices are told apart by the voice converter: download it on the Models screen and turn character memory on.';

  @override
  String sceneVoiceUnknown(int number) {
    return 'Voice $number';
  }

  @override
  String get sceneVoiceAnonymous => 'Nobody in particular';

  @override
  String sceneVoiceLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '$count line',
    );
    return '$_temp0';
  }

  @override
  String get sceneVoiceReadAs => 'Read as';

  @override
  String get sceneVoiceAsHeard => 'As heard';

  @override
  String get sceneVoiceNoCharacters =>
      'Record characters on the Characters screen, then draw who reads whom on the Graph.';

  @override
  String sceneVoiceReplaced(String name) {
    return 'Read as “$name”';
  }

  @override
  String failureOcrLanguageMissing(String language) {
    return 'Windows has no text recognition installed for $language. Add the language in Settings → Time & language → Language & region → Add a language.';
  }

  @override
  String get textLanguageLabel => 'Text language';

  @override
  String get textLanguageNote => 'Text in the dubbing language is voiced untranslated';

  @override
  String startingProgress(int percent) {
    return 'Starting $percent%';
  }

  @override
  String get startingPlain => 'Starting';

  @override
  String latencyMs(int value) {
    return '$value ms';
  }

  @override
  String get emptyTranscript => 'Recognized and translated lines will appear here';

  @override
  String get transcriptClear => 'Clear';

  @override
  String get transcriptClearTooltip => 'Remove every line from the list';

  @override
  String get pipelineSummaryDirect => 'Whisper → English → Silero';

  @override
  String get pipelineSummaryOcrDirect => 'Windows OCR → English → Silero';

  @override
  String pipelineSummary(String language) {
    return 'Whisper → English → Marian → $language → Silero';
  }

  @override
  String pipelineSummaryOcr(String language) {
    return 'Windows OCR → English → Marian → $language → Silero';
  }

  @override
  String get sectionRecognition => 'SPEECH RECOGNITION';

  @override
  String get sectionRecognitionNote =>
      'Whisper turns speech in any language into English text. One model covers everything — larger is more accurate and slower.';

  @override
  String get sectionLanguages => 'DUBBING LANGUAGES';

  @override
  String get sectionLanguagesNote =>
      'A language\'s translator and voice are downloaded, picked and deleted together. Only the language you play in is needed. English needs no translator: whisper hands English over already.';

  @override
  String get modelPartTranslation => 'translation';

  @override
  String get modelPartVoice => 'voice';

  @override
  String get modelPartConverter => 'voice converter';

  @override
  String get languageHintSelect => 'Click to dub into this language';

  @override
  String get languageHintSelected => 'Dubbing goes into this language';

  @override
  String get languageHintLocked => 'The language can be changed once dubbing is stopped';

  @override
  String get languageRemoveTitle => 'Delete the language?';

  @override
  String languageRemoveMessage(String language, String size) {
    return 'The $language translator and voice ($size) will be deleted from disk. They can be downloaded again at any time.';
  }

  @override
  String get converterHintInUse => 'In use by Original voice mode';

  @override
  String get converterHintIdle => 'Needed only by Original voice mode';

  @override
  String get modelInstalled => 'Installed';

  @override
  String get downloadPause => 'Pause';

  @override
  String get downloadResume => 'Resume';

  @override
  String get downloadCancel => 'Cancel';

  @override
  String get downloadPaused => 'Paused';

  @override
  String get downloadStopping => 'Stopping…';

  @override
  String get downloadCancelNotResumable => 'Cancel (cannot be resumed)';

  @override
  String get modelDownload => 'Download';

  @override
  String get ocrRegionNote =>
      'Drag a frame over the place where the game prints its subtitles. The screen below stands for the game window; the frame is kept as a share of it, so it fits any resolution.';

  @override
  String ocrRegionValue(int width, int height, int left, int top) {
    return 'Frame $width × $height% of the window, $left% from the left and $top% from the top';
  }

  @override
  String ocrRegionOfScreen(int width, int height, int left, int top) {
    return 'Frame $width × $height% of the screen, $left% from the left and $top% from the top';
  }

  @override
  String get ocrRegionHelp =>
      'Drag the frame to move it, and its corners and sides to resize it. From the keyboard, the arrows move it and Shift with the arrows resizes it.';

  @override
  String get ocrRegionReset => 'Reset';

  @override
  String get settingsOriginalVolume => 'Original audio';

  @override
  String get duckWhileSpeaking => 'Turn the game down only under the translation';

  @override
  String get duckWhileSpeakingNote =>
      'The game plays at its own volume while LoreDub is silent and steps aside for the length of every dubbed line. Off, it stays turned down for the whole session. A line the game starts while the dubbing speaks is heard by recognition as quietly as it would be then.';

  @override
  String originalVolumeValue(int percent) {
    return 'Volume of the game process while dubbing: $percent%';
  }

  @override
  String get settingsTtsSpeed => 'Speech rate';

  @override
  String get hurryWhenQueued => 'Read faster when lines are queued';

  @override
  String get hurryWhenQueuedNote =>
      'A line is read at the pace you set while the voice is free. From the third line waiting each adds a tenth, to no more than half again. When it is recognition that is behind rather than the voice, the pace is left alone: the queue there is not held by the voice.';

  @override
  String speedValue(String value) {
    return '$value×';
  }

  @override
  String get settingsVoice => 'Dubbing voice';

  @override
  String get voiceNote =>
      '\"Automatic\" matches a man\'s or a woman\'s voice to the original, and with remembered characters gives each of them a voice of their own. \"Original voice\" also carries the speaker\'s own timbre over into the dubbing.';

  @override
  String get voiceAutomatic => 'Automatic';

  @override
  String get voiceFixed => 'Choose';

  @override
  String get voiceFieldLabel => 'Voice';

  @override
  String get voiceUnavailable =>
      'This language\'s package ships voices of one gender only — you can pick one, but there is nothing to match.';

  @override
  String get voiceOriginal => 'Original voice';

  @override
  String get voiceOriginalNote =>
      'The original\'s timbre is laid over the Silero voice. On the processor each line sounds about a second later, on a graphics card with no noticeable delay: pick the device in the OpenVoice row under Device.';

  @override
  String get voiceOriginalMissing =>
      'This needs the voice converter: download it under Original voice on the Models screen.';

  @override
  String voiceOriginalSpeaking(String name) {
    return 'The original\'s timbre over $name';
  }

  @override
  String get voiceOverlap => 'Let different characters overlap';

  @override
  String get voiceOverlapNote =>
      'Another character\'s line starts at once instead of waiting for the current one to end; no more than two voices sound together. Without remembered characters they are told apart only by the gender of their voice.';

  @override
  String get voiceBank => 'Remember the characters\' voices';

  @override
  String get voiceBankOnNote =>
      'Every new character is remembered by their voice and given a Silero voice of their own — and their own timbre with Original voice on. Their later lines keep both, restarts included. Every game has a voice bank of its own.';

  @override
  String get voiceBankOffNote =>
      'Characters are not remembered: the voice is matched to the gender of each line afresh, and the timbre is taken from that line and never saved.';

  @override
  String voiceBankCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voices saved',
      one: '$count voice saved',
      zero: 'No voices saved',
    );
    return '$_temp0';
  }

  @override
  String get voiceBankClear => 'Clear';

  @override
  String get voiceBankClearTitle => 'Clear the voice bank?';

  @override
  String get voiceBankClearMessage =>
      'The saved voices of every game will be deleted. Characters will take their timbre afresh from their next lines.';

  @override
  String get voiceBankClearCancel => 'Cancel';

  @override
  String get voiceBankClearConfirm => 'Clear';

  @override
  String get sectionVoiceConversion => 'ORIGINAL VOICE';

  @override
  String get sectionVoiceConversionNote =>
      'Only needed for the Original voice mode: it carries the speaker\'s timbre over into the dubbing. One converter serves every language.';

  @override
  String modelConverterTitle(String version) {
    return 'OpenVoice $version voice converter';
  }

  @override
  String modelConverterNote(String size) {
    return 'Moves the timbre of the original line onto the Silero voice, $size.';
  }

  @override
  String get stageConverter => 'Loading the voice converter';

  @override
  String voiceSpeaking(String name) {
    return 'Now speaking: $name';
  }

  @override
  String get voiceGenderMale => 'male';

  @override
  String get voiceGenderFemale => 'female';

  @override
  String performanceNote(int cores, int recommended) {
    return 'Recognition takes most of the delay and scales well with threads. Cores available: $cores, recommended $recommended.';
  }

  @override
  String get cpuThreads => 'CPU threads';

  @override
  String get roughRecognition => 'Recognize faster, more roughly';

  @override
  String get roughRecognitionNote =>
      'Whisper listens over a shortened stretch of sound. On nine clips measured, recognition took 897 ms rather than 1329 and the words came back the same on all nine, two of them differing only by a comma. Fast or unclear speech will cost more mistakes. Translation and the voice are not affected.';

  @override
  String get settingsPython => 'Python runtime';

  @override
  String get pythonNote =>
      'Marian and Silero run on the python.exe you pick. The setup ships a ready runtime.';

  @override
  String get pythonFieldLabel => 'Python path or command';

  @override
  String get pythonFieldHelper => 'A full path, or python.exe resolved from PATH.';

  @override
  String get pythonFieldRequired => 'Name a python.exe';

  @override
  String get pythonSearching => 'Searching…';

  @override
  String get pythonFindAutomatically => 'Find automatically';

  @override
  String get pythonBundled => 'Bundled';

  @override
  String get save => 'Save';

  @override
  String get settingsModelDownloads => 'Model downloads';

  @override
  String get proxyNote => 'An optional HTTP or SOCKS5 proxy is used for model downloads only.';

  @override
  String get proxyLabel => 'HTTP / SOCKS5 proxy';

  @override
  String get proxyHelper => 'Format: http://… or socks5://user:password@host:port. Stored locally.';

  @override
  String get settingsModelDirectory => 'Model directory';

  @override
  String get modelDirectoryNote => 'Whisper, Marian and Silero are kept on this machine.';

  @override
  String get openInExplorer => 'Open in Explorer';

  @override
  String get settingsInterfaceLanguage => 'Interface language';

  @override
  String get interfaceLanguageNote => 'Applies immediately, without a restart.';

  @override
  String get settingsGroupInterface => 'INTERFACE';

  @override
  String get settingsGroupDubbing => 'DUBBING';

  @override
  String get settingsGroupCompute => 'COMPUTE';

  @override
  String get settingsScale => 'Scale';

  @override
  String scaleValue(int percent) {
    return '$percent%';
  }

  @override
  String get scaleNote =>
      'Makes the whole interface larger or smaller at once, leaving the Windows scale alone: this window often sits beside a game that took the screen.';

  @override
  String get settingsGroupDownloads => 'DOWNLOADS';

  @override
  String get settingsGroupPaths => 'PATHS';

  @override
  String modelWhisperTitle(String version) {
    return 'Whisper $version';
  }

  @override
  String get modelWhisperNote =>
      'Speech recognition and translation of any language into English. One model for every dubbing language.';

  @override
  String get whisperAxisSize => 'Size';

  @override
  String get whisperAxisQuality => 'Quality';

  @override
  String get whisperQualityFair => 'fair';

  @override
  String get whisperQualityGood => 'good';

  @override
  String get whisperQualityExcellent => 'excellent';

  @override
  String get whisperLegendMissing => 'not downloaded';

  @override
  String get whisperLegendInstalled => 'downloaded';

  @override
  String get whisperLegendSelected => 'selected';

  @override
  String get whisperLegendDownloading => 'downloading';

  @override
  String get whisperNoTranslation => 'no translation';

  @override
  String whisperHintDownload(String size) {
    return 'Click to download ($size)';
  }

  @override
  String get whisperHintSelect => 'Click to use it';

  @override
  String get whisperHintSelected => 'In use for recognition';

  @override
  String get whisperHintLocked => 'The model can be changed once dubbing is stopped';

  @override
  String whisperDownloadProgress(int percent, String done, String total) {
    return '$percent% · $done of $total';
  }

  @override
  String get modelWhisperTranscribeOnly =>
      'Does not translate speech: only suits an original already in English.';

  @override
  String get recognitionNeedsEnglish =>
      'The chosen model does not translate speech, and the original language is not set to English.';

  @override
  String modelTranslationNote(String size) {
    return 'Local Helsinki-NLP/Marian translator, $size.';
  }

  @override
  String modelTranslationTitle(String language) {
    return 'English → $language';
  }

  @override
  String modelVoiceTitle(String language, String version) {
    return '$language — Silero $version';
  }

  @override
  String modelVoiceNote(String language) {
    return '$language speech, 24 kHz.';
  }

  @override
  String get modelVoiceNoteRu =>
      'Russian speech, 24 kHz; voices xenia, aidar, baya, kseniya and eugene.';

  @override
  String get language_ar => 'Arabic';

  @override
  String get language_cs => 'Czech';

  @override
  String get language_de => 'German';

  @override
  String get language_en => 'English';

  @override
  String get language_es => 'Spanish';

  @override
  String get language_fr => 'French';

  @override
  String get language_it => 'Italian';

  @override
  String get language_ja => 'Japanese';

  @override
  String get language_ko => 'Korean';

  @override
  String get language_nl => 'Dutch';

  @override
  String get language_pl => 'Polish';

  @override
  String get language_pt => 'Portuguese';

  @override
  String get language_ru => 'Russian';

  @override
  String get language_sv => 'Swedish';

  @override
  String get language_tr => 'Turkish';

  @override
  String get language_uk => 'Ukrainian';

  @override
  String get language_zh => 'Chinese';

  @override
  String get translationTarget_ru => 'Russian';

  @override
  String get translationTarget_de => 'German';

  @override
  String get translationTarget_es => 'Spanish';

  @override
  String get translationTarget_fr => 'French';

  @override
  String get translationTarget_uk => 'Ukrainian';

  @override
  String get voiceName_ru => 'Russian voice';

  @override
  String get voiceName_de => 'German voice';

  @override
  String get voiceName_es => 'Spanish voice';

  @override
  String get voiceName_fr => 'French voice';

  @override
  String get voiceName_uk => 'Ukrainian voice';

  @override
  String get voiceSpeech_de => 'German';

  @override
  String get voiceSpeech_es => 'Spanish';

  @override
  String get voiceSpeech_fr => 'French';

  @override
  String get voiceSpeech_uk => 'Ukrainian';

  @override
  String failureWhisperMissing(String detail) {
    return 'whisper-cli.exe is missing: $detail. Install LoreDub from the setup, or prepare the runtime with scripts/prepare_windows_runtime.ps1.';
  }

  @override
  String failureWhisperModelMissing(String detail) {
    return 'The Whisper model is missing: $detail. Install it on the Models screen.';
  }

  @override
  String failureWhisperFailed(String detail) {
    return 'whisper.cpp: $detail';
  }

  @override
  String failurePythonMissing(String detail) {
    return 'No Python at $detail. Install LoreDub from the setup, or prepare the runtime with scripts/prepare_windows_runtime.ps1.';
  }

  @override
  String get failurePythonStoreAlias =>
      'PATH holds only the Microsoft Store alias instead of Python. It never starts an interpreter. Choose the bundled runtime, or name a python.exe that has torch, transformers and ctranslate2.';

  @override
  String get failurePythonSearchEmpty =>
      'No Python in PATH or in the standard installation directories. Name a python.exe yourself, or use the bundled runtime.';

  @override
  String failurePythonSearchNoDependencies(String detail) {
    return 'No Python with torch, transformers and ctranslate2. Inspected: $detail.';
  }

  @override
  String failurePythonSearchFailed(String detail) {
    return 'The search for Python failed: $detail';
  }

  @override
  String pythonCandidateWithoutDependencies(String path, String version) {
    return '$path (Python $version, no torch/transformers/ctranslate2)';
  }

  @override
  String pythonCandidateUnusable(String path) {
    return '$path (does not start)';
  }

  @override
  String failureWorkerExited(int code, String detail) {
    return 'The Marian/Silero worker exited with code $code: $detail';
  }

  @override
  String failureWorkerExitedSilently(int code) {
    return 'The Marian/Silero worker exited with code $code without a word. Check the python.exe you picked: it needs torch, transformers and ctranslate2.';
  }

  @override
  String failureWorkerTimeout(String detail) {
    return 'Marian/Silero did not answer within 2 minutes. Last output: $detail';
  }

  @override
  String get failureWorkerTimeoutSilent =>
      'Marian/Silero did not answer within 2 minutes, and printed nothing.';

  @override
  String get failureWorkerNotRunning => 'The Marian/Silero worker is not running';

  @override
  String get failureAudioNotDecoded => 'Windows could not read any of those files as sound';

  @override
  String failureWorkerFailed(String detail) {
    return 'Marian/Silero: $detail';
  }

  @override
  String get failurePipelineStopped => 'Dubbing was stopped';

  @override
  String get failureWindowsOnly => 'The local pipeline runs on Windows only';

  @override
  String get failureExplorerUnsupported => 'Opening a folder is supported on Windows only';

  @override
  String failureDownloadRejected(String detail) {
    return 'The server answered $detail';
  }

  @override
  String failureDownloadStalled(String detail) {
    return 'The download of $detail stalled: no data arrived, even after several reconnects. Press Download again — what arrived is kept.';
  }

  @override
  String failureVerificationFailed(String detail) {
    return '$detail failed verification';
  }

  @override
  String get failureSocksLookupFailed => 'The SOCKS5 proxy address could not be resolved';

  @override
  String get failureProxyFormat => 'Use the form http://host:port or socks5://host:port';

  @override
  String get failureProxyPort => 'The proxy port has to be between 1 and 65535';

  @override
  String failureModelRemoveFailed(String detail) {
    return 'The model could not be deleted: $detail';
  }

  @override
  String get modelRemove => 'Delete';

  @override
  String get modelRemoveInUse => 'The model in use cannot be deleted while dubbing runs';

  @override
  String get modelRemoveTitle => 'Delete the model?';

  @override
  String modelRemoveMessage(String name, String size) {
    return '$name ($size) will be deleted from disk. It can be downloaded again at any time.';
  }

  @override
  String get modelRemoveConfirm => 'Delete';

  @override
  String get modelRemoveCancel => 'Keep';

  @override
  String failureVoiceBankClearFailed(String detail) {
    return 'The voice bank could not be cleared: $detail';
  }

  @override
  String failureInitializationFailed(String detail) {
    return 'The application could not start: $detail';
  }

  @override
  String failureCaptureFailed(String detail) {
    return 'Capture stopped: $detail';
  }

  @override
  String get settingsComputeDevice => 'Compute device';

  @override
  String get computeDeviceNote =>
      '\"Automatic\" finds the graphics card by itself. Each model can be moved to a different device on its own.';

  @override
  String get computeDeviceAuto => 'Automatic';

  @override
  String get computeDeviceGpu => 'GPU';

  @override
  String get computeDeviceCpu => 'CPU';

  @override
  String get computeStageRecognition => 'Whisper';

  @override
  String get computeStageTranslation => 'Translation';

  @override
  String get computeStageSpeech => 'Speech';

  @override
  String get computeStageVoiceConversion => 'OpenVoice';

  @override
  String get computeBackendCuda => 'CUDA';

  @override
  String get computeBackendVulkan => 'Vulkan';

  @override
  String get computeBackendCpu => 'CPU';

  @override
  String computeAdapterDetected(String name) {
    return 'Graphics card: $name';
  }

  @override
  String get computeNoAdapter => 'No usable graphics card found — everything runs on the processor';

  @override
  String get computeBackendUnsupported => 'This model has no such build';

  @override
  String get computeBackendNoHardware => 'No suitable graphics card or driver';

  @override
  String get computeBackendNotShipped =>
      'This copy has no such build: the Vulkan build of Whisper is in the installer only when it could be compiled';

  @override
  String computeRuntimeMissing(String size) {
    return 'Needs a $size package';
  }

  @override
  String get computeRuntimeDownload => 'Download';

  @override
  String get computeRuntimeRemove => 'Remove';

  @override
  String get computeRuntimeRemoveTitle => 'Remove it?';

  @override
  String computeRuntimeRemoveMessage(String size) {
    return 'The $size package will be deleted from disk and the stage will go back to the processor. It can be downloaded again at any time.';
  }

  @override
  String get computeRuntimeRemoveConfirm => 'Remove completely';

  @override
  String get computeRuntimeRemoveCancel => 'Keep';

  @override
  String get computeRuntimeInstalling => 'Installing…';

  @override
  String get computeRuntimesTitle => 'GRAPHICS CARD PACKAGES';

  @override
  String get runtimeWhisperCuda => 'CUDA · Whisper';

  @override
  String get runtimeTorchCuda => 'CUDA · translation';

  @override
  String get runtimeServesWhisper => 'recognition';

  @override
  String get runtimeServesTorch => 'translation, speech and OpenVoice';

  @override
  String get runtimeHintInUse => 'In use now';

  @override
  String get runtimeHintIdle => 'Downloaded, but no stage uses it now';

  @override
  String get runtimeRemoveLocked => 'The package can be deleted once dubbing is stopped';

  @override
  String computeRuntimeDownloading(String size) {
    return 'The $size package is downloading — pause and cancel are on its tile below';
  }

  @override
  String get computeCellHintDownload => 'Click to download';

  @override
  String get computeCellSelect => 'Click to run this stage here';

  @override
  String get computeCellSelected => 'This stage runs here';

  @override
  String get computeCellLocked => 'The device can be changed once dubbing is stopped';

  @override
  String get computeSpeechNote =>
      'Speech gains little from the card: Silero holds at 20-26 ms whatever the line is worth, against 23-66 ms on the processor, and the first phrase of a session costs a second more. Next to recognition, which is measured in seconds, the difference is hard to hear.';

  @override
  String failureRuntimeIncomplete(String detail) {
    return 'The downloaded package has no $detail';
  }

  @override
  String failureRuntimeInstallFailed(String detail) {
    return 'The GPU runtime could not be installed: $detail';
  }

  @override
  String updateCurrent(String version) {
    return 'Version $version';
  }

  @override
  String get updateChecking => 'Checking for updates…';

  @override
  String get updateUpToDate => 'This is the newest version';

  @override
  String get updateCheckAgain => 'Check for updates';

  @override
  String updateOpenRelease(String version) {
    return 'Open the page for version $version';
  }

  @override
  String get updateFailed => 'Could not check for updates';

  @override
  String get updateAvailableTitle => 'A new LoreDub is out';

  @override
  String updateFromTo(String current, String latest) {
    return 'Current version v$current → v$latest';
  }

  @override
  String get updateInstallHint => 'Click to download and install the update';

  @override
  String get updateDownloading => 'Downloading the update…';

  @override
  String get updateInstalled => 'Updated';

  @override
  String get updateRestart => 'Restart';

  @override
  String get updateRestartHint =>
      'LoreDub closes, installs the new version in a few seconds and opens again';

  @override
  String failureUpdateInstallFailed(String detail) {
    return 'The update could not be installed: $detail';
  }

  @override
  String updateAvailableBody(String version) {
    return 'Version $version is available. Click the versions line at the bottom left to update.';
  }

  @override
  String failureUpdateCheckFailed(String detail) {
    return 'Could not check for updates: $detail';
  }

  @override
  String get failureUnknown => 'Unknown error';

  @override
  String get stagePython => 'Starting Python';

  @override
  String get stageTorch => 'Loading PyTorch';

  @override
  String get stageTransformers => 'Loading Transformers';

  @override
  String get stageTranslator => 'Loading the translator';

  @override
  String get stageSpeech => 'Loading speech synthesis';

  @override
  String get stageCapture => 'Starting capture';

  @override
  String get navPipeline => 'Graph';

  @override
  String get titlePipeline => 'Pipeline graph';

  @override
  String get pipelineGraphHint =>
      'Drag from one socket to another to lay the path. The wheel zooms; empty space drags the canvas. Shift-click chooses several nodes, Ctrl-drag draws a band around them, and what is chosen moves together.';

  @override
  String failurePipelinesSaveFailed(String detail) {
    return 'The schemes could not be saved: $detail';
  }

  @override
  String failurePipelinesExportFailed(String detail) {
    return 'The scheme could not be written: $detail';
  }

  @override
  String failurePipelinesImportFailed(String detail) {
    return 'There is no LoreDub scheme in “$detail”.';
  }

  @override
  String get pipelineSchemes => 'Saved schemes';

  @override
  String get pipelineSaveScheme => 'Save the scheme';

  @override
  String get pipelineSchemeName => 'Name of the scheme';

  @override
  String get pipelineSchemeNew => 'New scheme';

  @override
  String get pipelineSchemesEmpty =>
      'No schemes kept yet. Save the scheme keeps this one — the route, where the nodes sit and which cards are on the canvas — so you can come back to it.';

  @override
  String get pipelineSchemeApply => 'Draw this scheme';

  @override
  String get pipelineSchemeExport => 'Write the scheme to a file';

  @override
  String get pipelineSchemeImport => 'Read a scheme from a file';

  @override
  String get pipelineSchemeDelete => 'Delete the scheme';

  @override
  String get pipelineSchemeReplace => 'Overwrite';

  @override
  String get pipelineSchemeRename => 'Rename';

  @override
  String get pipelineSchemeCancel => 'Cancel';

  @override
  String get pipelineSchemeAudio => 'Route drawn';

  @override
  String get pipelineSchemeUnrouted => 'No way in';

  @override
  String pipelineSchemeCast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count characters',
      one: 'one character',
    );
    return '$_temp0';
  }

  @override
  String get pipelineResetLayout => 'Lay out again';

  @override
  String get pipelineUndo => 'Undo';

  @override
  String get pipelineRedo => 'Redo';

  @override
  String get pipelineAddCharacter => 'Put a character on the graph';

  @override
  String get pipelineNoCharacters => 'No characters yet — record them on the Characters screen';

  @override
  String get pipelineSelected => 'Selected';

  @override
  String get pipelineCloseInspector => 'Close the panel';

  @override
  String get pipelineRemoveNode => 'Take off the graph';

  @override
  String get pipelineCutLink => 'Give the voice back';

  @override
  String get pipelineCutRoute => 'Take the original stream out';

  @override
  String get pipelineCutCast => 'Take the cast out of the mix';

  @override
  String get pipelineCutHeard => 'Stop counting this one among the voices of the game';

  @override
  String get pipelineCutTranslation => 'Take the translator out — the dubbing becomes English';

  @override
  String get pipelineCutTranslationBack => 'Put the translator back in the line';

  @override
  String get pipelineNodeSource => 'Original stream';

  @override
  String get pipelineNodeRecognition => 'Whisper';

  @override
  String get pipelineNodeTranslation => 'Translation';

  @override
  String get pipelineNoTranslation => 'Nothing to translate';

  @override
  String get pipelineNodeVoice => 'Lines';

  @override
  String get pipelineNodeOutput => 'Stream';

  @override
  String get pipelineSocketGameAudio => 'Audio';

  @override
  String get pipelineSocketSpeech => 'Speech';

  @override
  String get pipelineSocketText => 'Text';

  @override
  String get pipelineSocketAudio => 'Audio';

  @override
  String get pipelineSocketCast => 'Characters';

  @override
  String get pipelineSocketCharacter => 'Character';

  @override
  String get pipelineSocketVoice => 'Voice';

  @override
  String get pipelineUnrouted => 'not routed';

  @override
  String get pipelineNoProcess => 'No game selected';

  @override
  String get pipelineNoModel => 'No model selected';

  @override
  String get pipelineOutputDefault => 'Default device';

  @override
  String get pipelineMixOverlapping => 'overlapping';

  @override
  String get pipelineMixInTurn => 'in turn';

  @override
  String pipelineReadBy(String name) {
    return 'In $name\'s voice';
  }

  @override
  String get pipelineChained =>
      'This voice is given away in turn: a substitution is followed one hop only.';

  @override
  String get pipelineCharacterNeedsOriginal => 'needs the original voice';

  @override
  String get pipelineLockedNote =>
      'A session is running: the route and the models are settled until it stops.';

  @override
  String get pipelineModelLabel => 'Recognition model';

  @override
  String get pipelineRefusalSignal => 'A different signal arrives here.';

  @override
  String get pipelineRefusalDirection => 'A link runs from an output to an input.';

  @override
  String get pipelineRefusalSameNode => 'A node does not join itself.';

  @override
  String get pipelineRefusalUnsupported => 'The engine has no such route.';

  @override
  String get pipelineRefusalLoop => 'The characters would then voice each other.';

  @override
  String get pipelineRefusalLocked => 'The route cannot change while a session is running.';

  @override
  String get pipelineRefusalTranslatorMissing => 'Download a language with a translator first.';

  @override
  String failurePipelineLayoutSaveFailed(String detail) {
    return 'The graph could not be saved: $detail';
  }

  @override
  String get pipelineNodeMix => 'Mix';

  @override
  String pipelineMixVoices(int count) {
    return 'Up to $count voices at once';
  }

  @override
  String get pipelineMixOneVoice => 'One voice at a time';

  @override
  String pipelineMixNote(int count) {
    return 'Everything voiced goes through the mix — the pipeline\'s own voice and the characters\' lines alike. No more than $count voices sound together, and one character never talks over themselves.';
  }

  @override
  String pipelineOutputOriginal(int percent) {
    return 'original $percent%';
  }

  @override
  String get pipelineOutputNote => 'The dubbing goes to the default Windows output device.';
}
