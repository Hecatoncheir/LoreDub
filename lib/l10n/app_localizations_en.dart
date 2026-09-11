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
  String get navLive => 'Live';

  @override
  String get navModels => 'Models';

  @override
  String get navSettings => 'Settings';

  @override
  String get titleLive => 'Game dubbing';

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
  String get statusStopping => 'Stopping…';

  @override
  String get statusError => 'Error';

  @override
  String get modelsNeededTitle => 'The first run needs models';

  @override
  String get modelsNeededNote => 'They are downloaded separately and are not part of the setup.';

  @override
  String get modelsNeededAction => 'Open models';

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
  String get captureOcrNote =>
      'Subtitles are read off the selected game\'s window while it is in front';

  @override
  String get sourceSystem => 'All audio';

  @override
  String get sourceProcess => 'Process';

  @override
  String get refreshProcesses => 'Refresh the process list';

  @override
  String get targetLanguageLabel => 'Dubbing language';

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
  String get sectionTranslation => 'TEXT TRANSLATION MODELS';

  @override
  String get sectionTranslationNote => 'The English text is translated into the language you pick.';

  @override
  String get sectionSpeech => 'TEXT-TO-SPEECH MODELS';

  @override
  String get sectionSpeechNote => 'The voice has to speak the same language as the translation.';

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
  String get settingsCaptureSource => 'Text source';

  @override
  String get captureAudio => 'Game audio';

  @override
  String get captureOcr => 'Subtitles + OCR';

  @override
  String get settingsOcrRegion => 'Subtitle area';

  @override
  String get ocrRegionNote =>
      'Drag a frame over the place where the game prints its subtitles. The screen below stands for the game window; the frame is kept as a share of it, so it fits any resolution.';

  @override
  String ocrRegionValue(int width, int height, int left, int top) {
    return 'Frame $width × $height% of the window, $left% from the left and $top% from the top';
  }

  @override
  String get ocrRegionHelp =>
      'Drag the frame to move it, and its corners and sides to resize it. From the keyboard, the arrows move it and Shift with the arrows resizes it.';

  @override
  String get ocrRegionReset => 'Reset';

  @override
  String get settingsOriginalVolume => 'Original audio';

  @override
  String originalVolumeValue(int percent) {
    return 'Volume of the game process while dubbing: $percent%';
  }

  @override
  String get settingsTtsSpeed => 'Speech rate';

  @override
  String speedValue(String value) {
    return '$value×';
  }

  @override
  String get settingsVoice => 'Dubbing voice';

  @override
  String get voiceNote =>
      '\"Automatic\" matches a man\'s or a woman\'s voice to the original, line by line. \"Original voice\" also carries the speaker\'s timbre over into the dubbing.';

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
  String get voiceNeedsAudio =>
      'Subtitle mode never hears the original, so the chosen voice is used.';

  @override
  String get voiceOriginal => 'Original voice';

  @override
  String get voiceOriginalNote =>
      'The timbre is taken from every line and laid over the Silero voice. On the processor each line sounds about a second later.';

  @override
  String get voiceOriginalMissing =>
      'This needs the voice converter: download it under Original voice on the Models screen.';

  @override
  String voiceOriginalSpeaking(String name) {
    return 'The original\'s timbre over $name';
  }

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
  String get settingsPerformance => 'Performance';

  @override
  String performanceNote(int cores, int recommended) {
    return 'Recognition takes most of the delay and scales well with threads. Cores available: $cores, recommended $recommended.';
  }

  @override
  String get cpuThreads => 'CPU threads';

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
  String modelWhisperTitle(String version) {
    return 'Whisper $version';
  }

  @override
  String get modelWhisperNote =>
      'Speech recognition and translation of any language into English. One model for every dubbing language.';

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
      'PATH holds only the Microsoft Store alias instead of Python. It never starts an interpreter. Choose the bundled runtime, or name a python.exe that has torch and transformers.';

  @override
  String get failurePythonSearchEmpty =>
      'No Python in PATH or in the standard installation directories. Name a python.exe yourself, or use the bundled runtime.';

  @override
  String failurePythonSearchNoDependencies(String detail) {
    return 'No Python with torch and transformers. Inspected: $detail.';
  }

  @override
  String failurePythonSearchFailed(String detail) {
    return 'The search for Python failed: $detail';
  }

  @override
  String pythonCandidateWithoutDependencies(String path, String version) {
    return '$path (Python $version, no torch/transformers)';
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
    return 'The Marian/Silero worker exited with code $code without a word. Check the python.exe you picked: it needs torch and transformers.';
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
  String get computeSpeechCpuOnly =>
      'Silero runs on the processor: moving it to the card costs more than the work itself.';

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
  String updateAvailableBody(String version) {
    return 'Version $version is available. Use the arrow beside the version number to open the release page.';
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
}
