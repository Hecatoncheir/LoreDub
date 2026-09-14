// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// A character's voice, measured from the recordings the player dropped onto
/// their card.
///
/// The files are averaged rather than chosen between: leaving each of 36
/// measured clips out in turn, the held-out clip sits closer to the average
/// of the rest than to any single other clip of the same character 36 times
/// out of 36, by 0.076 of cosine on average. What several files buy is the
/// centre of a voice instead of the quirks of one line of it.
///
/// What it cannot do is tell a stranger from an odd line of the right
/// character: two clips of one character meet anywhere from 0.57 to 0.94,
/// two clips of different characters at up to 0.80, and those spreads
/// overlap. So nothing is thrown away on suspicion — only what is not a
/// voice at all — and the numbers the player needs to judge by come back
/// with the result.
class BuiltVoice {
  const BuiltVoice({
    this.vector = const [],
    this.gender,
    this.seconds = 0,
    this.used = 0,
    this.skipped = const [],
    this.agreement = 0,
    this.weakest = 0,
    this.together = true,
    this.anchor,
  });

  /// The fingerprint itself, as the card keeps it.
  final List<double> vector;
  final String? gender;

  /// How much speech went into it, over every file used.
  final double seconds;

  /// How many of the dropped files the fingerprint was taken from.
  final int used;

  /// The files that held no voice to measure — unreadable, too short, or
  /// nothing to do with the rest.
  final List<String> skipped;

  /// How closely the files agreed with the fingerprint they made, and how
  /// far the loosest of them sat from it. One file agrees with itself, so
  /// neither number says anything until there are two.
  final double agreement;
  final double weakest;

  /// Whether the set holds together as one voice. A character's own clips
  /// sit at 0.875 to 0.932 around their average, two characters mixed by
  /// mistake at 0.746 to 0.864 — so this catches most mixed sets and cannot
  /// catch two voices that genuinely sound alike.
  final bool together;

  /// The file whose voice stands closest to the result, which is the one the
  /// card keeps to play back.
  final String? anchor;

  bool get isEmpty => vector.isEmpty;

  static BuiltVoice fromJson(Map<String, Object?> json) => BuiltVoice(
    vector: [
      for (final value in json['vector'] as List<Object?>? ?? const [])
        if (value is num) value.toDouble(),
    ],
    gender: json['gender'] as String?,
    seconds: (json['seconds'] as num?)?.toDouble() ?? 0,
    used: (json['used'] as num?)?.toInt() ?? 0,
    skipped: [
      for (final value in json['skipped'] as List<Object?>? ?? const [])
        if (value is String) value,
    ],
    agreement: (json['agreement'] as num?)?.toDouble() ?? 0,
    weakest: (json['weakest'] as num?)?.toDouble() ?? 0,
    together: json['together'] as bool? ?? true,
    anchor: json['anchor'] as String?,
  );
}
