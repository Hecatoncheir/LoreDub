// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../data/services/playback_scheduler.dart';
import '../../domain/app_settings.dart';
import '../../domain/character.dart';
import '../../domain/compute_device.dart';
import '../../domain/pipeline_graph.dart';
import '../compute_names.dart';
import '../language_names.dart';
import '../model_names.dart';
import '../theme.dart';
import 'cubits/dashboard_cubits.dart';
import 'cubits/pipeline_graph_bloc.dart';
import 'cubits/shell_cubit.dart';
import 'pipeline_canvas.dart';
import 'process_picker.dart';

/// What the node the player clicked is set to, and the controls that change
/// it.
///
/// Nothing is configured here that is not configured elsewhere: the panel
/// writes into the same settings the Signal setup screen does, so a node is
/// a second way to the same switch rather than a second switch.
class PipelineInspector extends StatelessWidget {
  const PipelineInspector({
    super.key,
    required this.cubits,
    required this.node,
    required this.facts,
    required this.availability,
    this.chained = const {},
  });

  static const double width = 320;

  final DashboardCubits cubits;
  final PipelineNode node;
  final PipelineFacts facts;
  final ComputeAvailability availability;

  /// The cards whose reader is read by a third, which the substitution does
  /// not follow. Taken from the graph, which worked it out for the canvas.
  final Set<String> chained;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: width,
      child: Card(
        elevation: 3,
        shadowColor: const Color(0x22171717),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context, l10n),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                children: [
                  if (facts.running && node.kind != PipelineNodeKind.character)
                    _Note(text: l10n.pipelineLockedNote),
                  ..._fields(context, l10n),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.pipelineSelected.toUpperCase(),
                style: const TextStyle(
                  fontFamily: LoreDubFonts.mono,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: LoreDubPalette.mutedInk,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _title(l10n),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: l10n.pipelineCloseInspector,
          icon: const Icon(Icons.close_rounded, size: 18),
          onPressed: () => cubits.graph.add(const PipelineNodeSelected(null)),
        ),
      ],
    ),
  );

  String _title(AppLocalizations l10n) => switch (node.kind) {
    PipelineNodeKind.source => l10n.pipelineNodeSource,
    PipelineNodeKind.recognition => l10n.pipelineNodeRecognition,
    PipelineNodeKind.translation => l10n.pipelineNodeTranslation,
    PipelineNodeKind.voice => l10n.pipelineNodeVoice,
    PipelineNodeKind.mix => l10n.pipelineNodeMix,
    PipelineNodeKind.output => l10n.pipelineNodeOutput,
    PipelineNodeKind.character => facts.character(node.characterId)?.name ?? l10n.charactersNewName,
  };

  List<Widget> _fields(BuildContext context, AppLocalizations l10n) => switch (node.kind) {
    PipelineNodeKind.source => _source(l10n),
    PipelineNodeKind.recognition => _recognition(l10n),
    PipelineNodeKind.translation => _translation(l10n),
    PipelineNodeKind.voice => _voice(l10n),
    PipelineNodeKind.mix => _mix(l10n),
    PipelineNodeKind.output => _output(l10n),
    PipelineNodeKind.character => _character(context, l10n),
  };

  AppSettings get _settings => facts.settings;

  bool get _locked => facts.running;

  Future<void> _update(AppSettings value) => cubits.settings.update(value);

  List<Widget> _source(AppLocalizations l10n) => [
    Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ProcessPicker(
        processes: cubits.pipeline.state.processes,
        selected: facts.process,
        // The characters screen holds the game it records through, and this
        // is the same choice under another window.
        enabled: !_locked && !facts.recordingVoice,
        onSelected: cubits.pipeline.selectProcess,
        onRefresh: cubits.pipeline.refreshProcesses,
      ),
    ),
    _Field(
      label: l10n.settingsCaptureSource,
      child: _Choices<CaptureMode>(
        value: _settings.captureMode,
        enabled: !_locked,
        options: {
          CaptureMode.audio: l10n.captureAudio,
          CaptureMode.ocr: l10n.captureOcr,
        },
        onChanged: (value) => _update(_settings.copyWith(captureMode: value)),
      ),
    ),
    if (_settings.captureMode == CaptureMode.audio)
      _Field(
        label: l10n.sourceSystem,
        child: _Choices<AudioCaptureSource>(
          value: _settings.audioCaptureSource,
          enabled: !_locked,
          options: {
            AudioCaptureSource.process: l10n.sourceProcess,
            AudioCaptureSource.system: l10n.sourceSystem,
          },
          onChanged: (value) => _update(_settings.copyWith(audioCaptureSource: value)),
        ),
      ),
    _Note(
      text: switch (_settings.captureMode) {
        CaptureMode.ocr => l10n.captureOcrNote,
        _ =>
          _settings.audioCaptureSource == AudioCaptureSource.process
              ? l10n.captureProcessNote
              : l10n.captureSystemNote,
      },
    ),
  ];

  List<Widget> _recognition(AppLocalizations l10n) => [
    if (node.bypassed) _Note(text: l10n.pipelineRecognitionBypassed),
    _Field(
      label: l10n.pipelineModelLabel,
      child: DropdownButtonFormField<String>(
        key: ValueKey('graph-model-${facts.selection.recognition?.model.id}'),
        initialValue: facts.selection.recognition?.model.id,
        isExpanded: true,
        items: [
          for (final install in facts.selection.recognitionModels)
            if (install.installed)
              DropdownMenuItem(
                value: install.model.id,
                child: Text(whisperShortName(install.model), maxLines: 1),
              ),
        ],
        onChanged: _locked
            ? null
            : (value) => value == null ? null : cubits.settings.selectRecognitionModel(value),
      ),
    ),
    _device(l10n, ComputeStage.recognition),
  ];

  List<Widget> _translation(AppLocalizations l10n) => [
    _Field(
      label: l10n.targetLanguageLabel,
      child: DropdownButtonFormField<String>(
        key: ValueKey('graph-language-${_settings.targetLanguage}'),
        initialValue: _settings.targetLanguage,
        isExpanded: true,
        items: [
          for (final pair in facts.selection.languagePairs)
            DropdownMenuItem(
              value: pair.language,
              enabled: facts.selection.isLanguageReady(pair.language),
              child: Text(
                facts.selection.isLanguageReady(pair.language)
                    ? translationTargetName(l10n, pair.language)
                    : l10n.languageWithoutModels(translationTargetName(l10n, pair.language)),
                maxLines: 1,
              ),
            ),
        ],
        onChanged: _locked
            ? null
            : (value) => value == null ? null : cubits.settings.selectTargetLanguage(value),
      ),
    ),
    _device(l10n, ComputeStage.translation),
  ];

  List<Widget> _voice(AppLocalizations l10n) => [
    _Field(
      label: l10n.settingsVoice,
      child: _Choices<VoiceMode>(
        value: _settings.voiceMode,
        enabled: !_locked,
        options: {
          VoiceMode.automatic: l10n.voiceAutomatic,
          VoiceMode.chosen: l10n.voiceFixed,
          if (facts.selection.canUseOriginalVoice) VoiceMode.original: l10n.voiceOriginal,
        },
        onChanged: (value) => _update(_settings.withVoiceMode(value)),
      ),
    ),
    if (_settings.voiceMode == VoiceMode.chosen)
      _Field(
        label: l10n.voiceFieldLabel,
        child: DropdownButtonFormField<String>(
          key: ValueKey('graph-voice-${facts.selection.voice}'),
          initialValue: facts.selection.voice,
          isExpanded: true,
          items: [
            for (final option in facts.selection.availableVoices)
              DropdownMenuItem(
                value: option.id,
                child: Text(voiceLabel(l10n, option), maxLines: 1),
              ),
          ],
          onChanged: _locked
              ? null
              : (value) => value == null ? null : _update(_settings.copyWith(voice: value)),
        ),
      ),
    _Field(
      label:
          '${l10n.settingsTtsSpeed} · '
          '${l10n.speedValue(_settings.chosenSpeed.toStringAsFixed(2))}',
      // The same range as the settings screen, for the same reason as the
      // volume: a pace set here is one the other screen can set again.
      child: Slider(
        key: const ValueKey('graphTtsSpeed'),
        value: _settings.chosenSpeed,
        min: AppSettings.slowestSpeech,
        max: AppSettings.fastestSpeech,
        divisions: AppSettings.speechDivisions,
        onChanged: _locked ? null : (value) => _update(_settings.copyWith(ttsSpeed: value)),
      ),
    ),
    _Toggle(
      label: l10n.hurryWhenQueued,
      value: _settings.hurryWhenQueued,
      enabled: !_locked,
      onChanged: (value) => _update(_settings.copyWith(hurryWhenQueued: value)),
    ),
    _Note(text: l10n.hurryWhenQueuedNote),
    if (facts.selection.needsVoiceConverter) _device(l10n, ComputeStage.voiceConversion),
    _Toggle(
      label: l10n.voiceBank,
      value: _settings.voiceBank,
      enabled: !_locked,
      onChanged: (value) => _update(_settings.copyWith(voiceBank: value)),
    ),
  ];

  List<Widget> _mix(AppLocalizations l10n) => [
    _Toggle(
      label: l10n.voiceOverlap,
      value: _settings.overlapVoices,
      enabled: !_locked,
      onChanged: (value) => _update(_settings.copyWith(overlapVoices: value)),
    ),
    _Note(text: l10n.voiceOverlapNote),
    _Note(text: l10n.pipelineMixNote(overlappingVoices)),
  ];

  List<Widget> _output(AppLocalizations l10n) => [
    _Field(
      label:
          '${l10n.settingsOriginalVolume} · '
          '${l10n.originalVolumeValue((_settings.duckedVolume * 100).round())}',
      // The same range as the settings screen: a number set here is one the
      // other screen can set again.
      child: Slider(
        key: const ValueKey('graphOriginalVolume'),
        value: _settings.duckedVolume,
        min: _settings.quietestDuck,
        max: AppSettings.loudestDuck,
        divisions: _settings.duckDivisions,
        onChanged: _locked ? null : (value) => _update(_settings.copyWith(originalVolume: value)),
      ),
    ),
    _Toggle(
      label: l10n.duckWhileSpeaking,
      value: _settings.duckWhileSpeaking,
      enabled: !_locked,
      onChanged: (value) => _update(_settings.copyWith(duckWhileSpeaking: value)),
    ),
    _Note(text: l10n.duckWhileSpeakingNote),
    _Note(text: l10n.pipelineOutputNote),
  ];

  List<Widget> _character(BuildContext context, AppLocalizations l10n) {
    final character = facts.character(node.characterId);
    if (character == null) return [_Note(text: l10n.charactersEmpty)];
    return [
      _Field(
        label: l10n.charactersNameLabel,
        child: _NameField(
          // Keyed by the card, so opening another node starts a field on
          // that one's name rather than carrying this one's over.
          key: ValueKey('graph-name-${character.id}'),
          character: character,
          onRename: (name) => cubits.characters.rename(character.id, name),
        ),
      ),
      _Field(
        label: l10n.sceneVoiceReadAs,
        child: DropdownButtonFormField<String?>(
          key: ValueKey('graph-reader-${character.id}-${character.voicedBy}'),
          initialValue: character.voicedBy,
          isExpanded: true,
          items: [
            DropdownMenuItem(value: null, child: Text(l10n.charactersOwnVoice)),
            for (final other in facts.characters)
              if (other.id != character.id)
                DropdownMenuItem(value: other.id, child: Text(other.name, maxLines: 1)),
          ],
          onChanged: (value) => cubits.characters.voiceAs(character.id, value),
        ),
      ),
      if (chained.contains(character.id)) _Note(text: l10n.pipelineChained),
      _Note(
        text: character.vector.isEmpty
            ? l10n.charactersNoVoice
            : l10n.charactersVoiceKept(
                character.seconds.toStringAsFixed(1),
                _gender(l10n, character),
              ),
      ),
      const SizedBox(height: 6),
      // One under the other: side by side in a panel this narrow, both
      // labels were cut — one of them across the middle of a word.
      OutlinedButton.icon(
        icon: const Icon(Icons.groups_rounded, size: 18),
        label: Text(l10n.navCharacters),
        onPressed: () => cubits.shell.selectSection(DashboardSection.characters),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.close_rounded, size: 18),
        label: Text(l10n.pipelineRemoveNode),
        onPressed: () => cubits.graph.add(PipelineCharacterRemoved(node.id)),
      ),
    ];
  }

  String _gender(AppLocalizations l10n, Character character) => switch (character.gender) {
    'male' => l10n.voiceGenderMale,
    'female' => l10n.voiceGenderFemale,
    _ => l10n.charactersGenderUnknown,
  };

  /// What a stage runs on, offered only where the machine can actually run it.
  Widget _device(AppLocalizations l10n, ComputeStage stage) {
    final downloads = cubits.downloads.state;
    final ready = [
      for (final backend in stageBackends(stage))
        if (downloads.isBackendReady(stage, backend)) backend,
    ];
    final current = facts.backendOf(stage, availability);
    return _Field(
      label: l10n.settingsComputeDevice,
      child: DropdownButtonFormField<ComputeBackend>(
        key: ValueKey('graph-device-${stage.name}-${current.name}'),
        initialValue: ready.contains(current) ? current : null,
        isExpanded: true,
        items: [
          for (final backend in ready)
            DropdownMenuItem(value: backend, child: Text(computeBackendName(l10n, backend))),
        ],
        onChanged: _locked || ready.length < 2
            ? null
            : (value) => value == null ? null : cubits.settings.selectStageBackend(stage, value),
      ),
    );
  }
}

/// A labelled control, the way the settings screen sets one out.
/// The card's name, changed from the node the player has open.
///
/// A widget of its own because the field needs a controller of its own: the
/// panel is rebuilt whenever anything on the canvas moves, and a name half
/// typed must not be thrown away by that.
class _NameField extends StatefulWidget {
  const _NameField({super.key, required this.character, required this.onRename});

  final Character character;
  final ValueChanged<String> onRename;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _name = TextEditingController(text: widget.character.name);

  @override
  void didUpdateWidget(_NameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A name changed elsewhere — on the characters screen, or by an import
    // landing on this card — is shown; what is being typed is left alone.
    if (widget.character.name != oldWidget.character.name && !_name.selection.isValid) {
      _name.text = widget.character.name;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _rename() {
    final name = _name.text.trim();
    if (name.isEmpty || name == widget.character.name) return;
    widget.onRename(name);
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _name,
    decoration: const InputDecoration(isDense: true),
    onEditingComplete: _rename,
    onTapOutside: (_) => _rename(),
  );
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: LoreDubPalette.mutedInk,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    ),
  );
}

/// A row of exclusive choices, kept narrow enough for the panel.
class _Choices<T> extends StatelessWidget {
  const _Choices({
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });

  final T value;
  final Map<T, String> options;
  final void Function(T value) onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final entry in options.entries)
        ChoiceChip(
          label: Text(entry.value),
          selected: entry.key == value,
          onSelected: enabled ? (_) => onChanged(entry.key) : null,
          selectedColor: LoreDubPalette.orange,
          backgroundColor: LoreDubPalette.raised,
          side: const BorderSide(color: LoreDubPalette.outline),
          showCheckmark: false,
        ),
    ],
  );
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final bool value;
  final void Function(bool value) onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Switch(value: value, onChanged: enabled ? onChanged : null),
      ],
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, height: 1.4, color: LoreDubPalette.mutedInk),
    ),
  );
}
