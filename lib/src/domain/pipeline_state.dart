// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// [paused] is a live session resting: the models stay loaded and capture
/// stays open, so resuming takes no startup at all.
enum PipelineStatus { idle, starting, listening, paused, stopping, error }

class TranscriptEntry {
  const TranscriptEntry({
    required this.original,
    required this.english,
    required this.translated,
    required this.latency,
  });

  final String original;
  final String english;
  final String translated;
  final Duration latency;
}
