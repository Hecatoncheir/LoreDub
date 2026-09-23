// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/pipeline_graph.dart';
import '../node_paint.dart';
import 'port_row.dart';
import 'node_metrics.dart';

/// A node's port rows, each labelled on the side its socket is on. The rows
/// stand where [NodeMetrics] puts the sockets, so the two are changed
/// together.
class NodePortRows extends StatelessWidget {
  const NodePortRows({
    super.key,
    required this.kind,
    required this.paint,
    this.scheme = PipelineScheme.live,
  });

  final PipelineNodeKind kind;
  final NodePaint paint;

  /// The scheme the node is drawn on: the Screen page's voice takes who is
  /// speaking on the row Эфир's leaves empty.
  final PipelineScheme scheme;

  /// The labels of each row, left and right, for [kind] on [scheme].
  static List<(String?, String?)> _labels(
    AppLocalizations l10n,
    PipelineNodeKind kind,
    PipelineScheme scheme,
  ) => switch (kind) {
    PipelineNodeKind.source => [(null, l10n.pipelineSocketGameAudio)],
    PipelineNodeKind.recognition => [(l10n.pipelineSocketSpeech, l10n.pipelineSocketText)],
    PipelineNodeKind.translation => [(l10n.pipelineSocketText, l10n.pipelineSocketText)],
    PipelineNodeKind.voice => [
      (l10n.pipelineSocketText, l10n.pipelineSocketAudio),
      (
        PipelineSocket.voiceSpeaker.drawnOn(scheme) ? l10n.pipelineSocketCharacter : null,
        l10n.pipelineSocketCast,
      ),
    ],
    PipelineNodeKind.mix => [
      (l10n.pipelineSocketAudio, l10n.pipelineSocketAudio),
      (l10n.pipelineSocketCast, null),
    ],
    PipelineNodeKind.output => [(l10n.pipelineSocketAudio, null)],
    PipelineNodeKind.character => [
      (l10n.pipelineSocketCharacter, l10n.pipelineSocketVoice),
      (l10n.pipelineSocketVoice, null),
    ],
    PipelineNodeKind.glossary => [(l10n.pipelineSocketText, l10n.pipelineSocketText)],
    PipelineNodeKind.screen => [(null, l10n.pipelineSocketText)],
    PipelineNodeKind.detection => [(l10n.pipelineSocketGameAudio, l10n.pipelineSocketCharacter)],
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (left, right) in _labels(AppLocalizations.of(context), kind, scheme))
        PortRow(paint: paint, left: left, right: right),
    ],
  );
}
