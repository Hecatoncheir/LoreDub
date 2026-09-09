// Copyright (c) 2026 GameLingo contributors.
// SPDX-License-Identifier: MIT

enum PipelineStatus { idle, starting, listening, stopping, error }

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
