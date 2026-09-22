// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

part of 'voice_capture_bloc.dart';

/// What a card's record button does when pressed.
enum RecordAction { start, stop }

/// What the characters screen can be doing to a card.
///
/// Several of them go on side by side -- a clip plays while another card
/// records, files are measured while a sample is spoken -- which is why they
/// are not one state of the screen; but each holds one card at a time.
enum CardActivity { recording, playing, previewing, building }

/// What the characters screen is doing with the engine: the session a voice
/// is recorded through, the take, a card measured from files, and what is
/// sounding.
class VoiceCaptureState extends Equatable {
  const VoiceCaptureState({
    this.status = PipelineStatus.idle,
    this.busy = const {},
    this.heardSeconds = 0,
    this.clips = const {},
    this.previewReady = false,
    this.built,
  });

  /// The recording session: idle until the screen starts it, listening once
  /// the converter is loaded and the game's audio is being captured.
  final PipelineStatus status;

  /// The card each activity is under way on: the one whose voice is being
  /// recorded, whose clip is sounding, whose sample is being spoken -- from
  /// the moment it is asked for, which on the first one means waiting for
  /// the speech model -- and whose voice is being measured from files
  /// dropped on it.
  final Map<CardActivity, String> busy;

  /// How much speech the recording has heard, so the card can say whether
  /// there is enough of it yet.
  final double heardSeconds;

  /// The cards that kept the clip their voice was taken from, so it can be
  /// played back. A card imported from someone else's file has the
  /// fingerprint without the audio and is not in here.
  final Set<String> clips;

  /// What came of the last measurement from files, and the card it was
  /// for. The screen's own: the card keeps only the fingerprint.
  final ({String id, BuiltVoice voice})? built;

  /// Whether the speech model is loaded and a sample costs no waiting.
  final bool previewReady;

  /// The card [activity] is under way on, if it is.
  String? cardDoing(CardActivity activity) => busy[activity];

  /// Whether [activity] is under way on [id].
  bool isDoing(CardActivity activity, String id) => busy[activity] == id;

  /// [activity] begun on [id].
  VoiceCaptureState doing(CardActivity activity, String id) =>
      copyWith(busy: {...busy, activity: id});

  /// [activity] over, whichever card it was on.
  VoiceCaptureState done(CardActivity activity) => copyWith(busy: {...busy}..remove(activity));

  bool get running => status == PipelineStatus.starting || status == PipelineStatus.listening;

  bool get recording => busy.containsKey(CardActivity.recording);

  /// Whether a card is being measured from files right now.
  bool get building => busy.containsKey(CardActivity.building);

  /// Whether [id] has a clip of its own to play.
  bool canPlay(String id) => clips.contains(id);

  /// Nothing is played over anything else: one clip or one sample at a time.
  bool get sounding =>
      busy.containsKey(CardActivity.playing) || busy.containsKey(CardActivity.previewing);

  /// Whether [id]'s own clip can be played now: it has one, and nothing
  /// else is sounding.
  bool canPlayClip(String id) => canPlay(id) && !sounding;

  /// Whether a card can be read aloud in the voice the dubbing would give
  /// it. A sample brings up a worker of its own, so it waits for a dubbing
  /// session ([dubbing]) as well as for this screen's own sessions, and it
  /// needs the voice package ([speechInstalled]).
  bool canPreview({required bool dubbing, required bool speechInstalled}) =>
      speechInstalled && !dubbing && !sounding && !running && !building;

  /// What the record button on [id] does now, or null when it does nothing:
  /// only a running session records, and only one card at a time.
  RecordAction? recordActionFor(String id) {
    if (!running) return null;
    if (isDoing(CardActivity.recording, id)) return RecordAction.stop;
    return recording ? null : RecordAction.start;
  }

  /// Whether files dropped on a card are measured into its voice. Like a
  /// sample, it brings up a worker of its own; it needs the converter
  /// ([converterInstalled]) to measure with.
  bool takesFiles({required bool dubbing, required bool converterInstalled}) =>
      converterInstalled && !dubbing && !building && !recording;

  VoiceCaptureState copyWith({
    PipelineStatus? status,
    Map<CardActivity, String>? busy,
    double? heardSeconds,
    Set<String>? clips,
    ({String id, BuiltVoice voice})? built,
    bool clearBuilt = false,
    bool? previewReady,
  }) => VoiceCaptureState(
    status: status ?? this.status,
    busy: busy ?? this.busy,
    heardSeconds: heardSeconds ?? this.heardSeconds,
    clips: clips ?? this.clips,
    built: clearBuilt ? null : built ?? this.built,
    previewReady: previewReady ?? this.previewReady,
  );

  @override
  List<Object?> get props => [status, busy, heardSeconds, clips, built, previewReady];
}
