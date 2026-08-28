import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/journal_analytics.dart';
import '../theme/mindset_theme.dart';
import 'common_widgets.dart';

class JournalEntryCard extends StatelessWidget {
  const JournalEntryCard({super.key, required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final mood = MoodOption(
      label: entry.displayMood,
      icon: entry.result?.icon ?? iconForEmotion(entry.displayMood),
      color: entry.result?.color ?? colorForEmotion(entry.displayMood),
    );
    final theme = Theme.of(context);

    return WellnessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.displayDate,
                  style: theme.textTheme.labelSmall,
                ),
              ),
              _EntrySignalIcons(entry: entry),
              const SizedBox(width: 8),
              MoodBadge(label: mood.label, icon: mood.icon, color: mood.color),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            entry.displayPreview,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _EntrySignalIcons extends StatelessWidget {
  const _EntrySignalIcons({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final hasAudio = entry.audioResult != null;
    final hasText =
        entry.textResult != null ||
        (entry.audioResult == null && entry.text.isNotEmpty);
    final hasTyping = entry.typingResult != null;
    final signals = <(IconData, String)>[
      if (hasText) (Icons.text_fields_outlined, 'Text AI'),
      if (hasAudio) (Icons.mic_none_outlined, 'Audio AI'),
      if (hasTyping) (Icons.keyboard_alt_outlined, 'Typing behaviour'),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final signal in signals)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Tooltip(
              message: signal.$2,
              child: Icon(signal.$1, size: 17, color: color),
            ),
          ),
      ],
    );
  }
}

class MoodSelector extends StatelessWidget {
  const MoodSelector({
    super.key,
    required this.selectedMood,
    required this.onSelected,
  });

  final String selectedMood;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final mood in MoodPalette.moods)
          ChoiceChip(
            selected: selectedMood == mood.label,
            onSelected: (_) => onSelected(mood.label),
            avatar: Icon(mood.icon, size: 18),
            label: Text(mood.label),
            selectedColor: mood.color.withValues(alpha: 0.35),
            backgroundColor: mood.color.withValues(alpha: 0.12),
            side: BorderSide(
              color: selectedMood == mood.label
                  ? mood.color
                  : Theme.of(context).dividerColor,
            ),
            labelStyle: Theme.of(context).textTheme.labelLarge,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
      ],
    );
  }
}

class VoiceRecorderCard extends StatelessWidget {
  const VoiceRecorderCard({
    super.key,
    required this.isRecording,
    required this.isBusy,
    required this.transcript,
    required this.statusMessage,
    required this.onToggleRecording,
    required this.onAnalyzeVoice,
  });

  final bool isRecording;
  final bool isBusy;
  final String transcript;
  final String statusMessage;
  final VoidCallback? onToggleRecording;
  final VoidCallback? onAnalyzeVoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WellnessCard(
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color:
                  (isRecording ? MindSetTheme.error : theme.colorScheme.primary)
                      .withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isRecording ? Icons.mic : Icons.mic_none,
              size: 42,
              color: isRecording
                  ? MindSetTheme.error
                  : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isRecording ? 'Listening...' : 'Voice reflection',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            statusMessage,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          if (transcript.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Transcript', style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(transcript, style: theme.textTheme.bodyLarge),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isBusy ? null : onToggleRecording,
            icon: Icon(isRecording ? Icons.stop : Icons.fiber_manual_record),
            label: Text(isRecording ? 'Stop recording' : 'Start recording'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: (isBusy || isRecording || onAnalyzeVoice == null)
                ? null
                : onAnalyzeVoice,
            icon: isBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(isBusy ? 'Analyzing voiceâ€¦' : 'Analyze voice'),
          ),
        ],
      ),
    );
  }
}

class ReflectionResultCard extends StatelessWidget {
  const ReflectionResultCard({super.key, required this.result});

  final EmotionResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WellnessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MoodBadge(
                label: result.label,
                icon: result.icon,
                color: result.color,
              ),
              const Spacer(),
              Text(
                '${result.confidencePercent.toStringAsFixed(1)}% match',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SignalTile(
                  label: 'Confidence',
                  value: result.confidenceLabel,
                  icon: Icons.verified_outlined,
                  color: result.color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SignalTile(
                  label: 'Certainty',
                  value: '${result.certaintyScore.toStringAsFixed(1)}%',
                  icon: Icons.speed_outlined,
                  color: MindSetTheme.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Mirror statement', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(result.mirrorStatement, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          Text('Simple summary', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(result.summary, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Text('Top emotions', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final emotion in result.topEmotions) ...[
            _EmotionScoreBar(score: emotion, color: result.color),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          Text('Valence', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          _ValenceBars(valence: result.valence),
          const SizedBox(height: 16),
          Text(
            'Entropy ${result.entropy.toStringAsFixed(3)}',
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in result.tags)
                Chip(
                  label: Text(tag),
                  avatar: const Icon(Icons.sell_outlined, size: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignalTile extends StatelessWidget {
  const _SignalTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: theme.textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(label, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmotionScoreBar extends StatelessWidget {
  const _EmotionScoreBar({required this.score, required this.color});

  final EmotionScore score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = (score.confidencePercent / 100).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(score.emotion, style: theme.textTheme.bodyMedium),
            ),
            Text(
              '${score.confidencePercent.toStringAsFixed(2)}%',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.14),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _ValenceBars extends StatelessWidget {
  const _ValenceBars({required this.valence});

  final ValenceScore valence;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ValenceRow(
          label: 'Positive',
          value: valence.positivePercent,
          color: MoodPalette.happy,
        ),
        const SizedBox(height: 8),
        _ValenceRow(
          label: 'Negative',
          value: valence.negativePercent,
          color: MoodPalette.angry,
        ),
        const SizedBox(height: 8),
        _ValenceRow(
          label: 'Neutral',
          value: valence.neutralPercent,
          color: MoodPalette.neutral,
        ),
      ],
    );
  }
}

class _ValenceRow extends StatelessWidget {
  const _ValenceRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalized = (value / 100).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 74,
          child: Text(label, style: theme.textTheme.labelSmall),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: normalized,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 48,
          child: Text(
            '${value.toStringAsFixed(1)}%',
            textAlign: TextAlign.right,
            style: theme.textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}

class PatternSummaryCard extends StatelessWidget {
  const PatternSummaryCard({
    super.key,
    required this.entries,
    required this.onViewReports,
  });

  final List<JournalEntry> entries;
  final VoidCallback onViewReports;

  @override
  Widget build(BuildContext context) {
    return WellnessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBox(icon: Icons.query_stats, color: MindSetTheme.info),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pattern summary',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_summaryText(), style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onViewReports,
            icon: const Icon(Icons.summarize_outlined),
            label: const Text('View report'),
          ),
        ],
      ),
    );
  }

  String _summaryText() {
    final analytics = JournalAnalytics(entries);
    if (entries.isEmpty) {
      return 'Save this entry to start building a real pattern summary.';
    }
    final valence = analytics.averageValence;
    return 'Your saved history is averaging ${valence.positivePercent.toStringAsFixed(0)}% positive, ${valence.negativePercent.toStringAsFixed(0)}% negative, and ${valence.neutralPercent.toStringAsFixed(0)}% neutral across ${analytics.totalAnalyzed} analyzed ${analytics.totalAnalyzed == 1 ? 'entry' : 'entries'}.';
  }
}

/// Clear three-way breakdown: voice tone, words, and combined result.
class MultimodalBreakdownCard extends StatelessWidget {
  const MultimodalBreakdownCard({
    super.key,
    required this.combined,
    this.voice,
    this.words,
    this.transcript,
    this.reason,
    this.strategy,
    this.derivedState,
    this.fusionSignals,
  });

  final EmotionResult combined;
  final EmotionResult? voice;
  final EmotionResult? words;
  final String? transcript;
  final String? reason;
  final String? strategy;
  final Map<String, dynamic>? derivedState;
  final Map<String, dynamic>? fusionSignals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WellnessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBox(
                icon: Icons.hub_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'How this voice was read',
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Three signals: how you sounded, what you said, and the combined result.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _SignalSourceTile(
            title: 'Voice tone',
            subtitle: 'From how you sounded (audio AI)',
            icon: Icons.graphic_eq_rounded,
            result: voice,
            emptyLabel: 'No clear voice-tone signal',
            accent: MindSetTheme.info,
          ),
          const SizedBox(height: 10),
          _SignalSourceTile(
            title: 'Words',
            subtitle: 'From your transcript (text AI)',
            icon: Icons.notes_rounded,
            result: words,
            emptyLabel: transcript == null || transcript!.trim().isEmpty
                ? 'No words detected yet'
                : 'Words found, but text AI had no result',
            accent: MindSetTheme.success,
          ),
          const SizedBox(height: 10),
          _SignalSourceTile(
            title: 'Combined',
            subtitle: 'Best overall reading for this reflection',
            icon: Icons.auto_awesome_rounded,
            result: combined,
            emptyLabel: 'No combined result',
            accent: theme.colorScheme.primary,
            emphasized: true,
          ),
          if (fusionSignals != null) ...[
            const SizedBox(height: 12),
            Text(
              'How the signals were combined',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Text AI has the main influence (70%). Voice tone adds supporting context (30%).',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (derivedState != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Combined emotional state',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    derivedState!['label']?.toString() ??
                        'Reflective mixed state',
                    style: theme.textTheme.titleLarge,
                  ),
                  if ((derivedState!['note']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      derivedState!['note'].toString(),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (reason != null && reason!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Why combined looks like this',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(reason!, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
          if (transcript != null && transcript!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('What we heard', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(transcript!, style: theme.textTheme.bodyLarge),
          ],
        ],
      ),
    );
  }
}

class _SignalSourceTile extends StatelessWidget {
  const _SignalSourceTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.result,
    required this.emptyLabel,
    required this.accent,
    this.emphasized = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final EmotionResult? result;
  final String emptyLabel;
  final Color accent;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final has =
        result != null &&
        result!.label.toLowerCase() != 'unknown' &&
        result!.confidencePercent > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: emphasized
              ? accent.withValues(alpha: 0.55)
              : theme.dividerColor,
          width: emphasized ? 1.4 : 1,
        ),
        color: emphasized ? accent.withValues(alpha: 0.07) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBox(icon: icon, color: accent, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 10),
                if (has) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      MoodBadge(
                        label: result!.label,
                        icon: result!.icon,
                        color: result!.color,
                      ),
                      Text(
                        '${result!.confidencePercent.toStringAsFixed(0)}% confidence',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                  if (result!.summary.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      result!.summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ] else
                  Text(
                    emptyLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.65,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Three-way text-journal view: typing behaviour, BERT text, and final fusion.
class TypingTextBreakdownCard extends StatelessWidget {
  const TypingTextBreakdownCard({
    super.key,
    required this.typing,
    required this.text,
    required this.fused,
    required this.fusionReason,
  });

  final TypingBehaviorResult typing;
  final EmotionResult text;
  final EmotionResult fused;
  final String fusionReason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WellnessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBox(
                icon: Icons.keyboard_alt_outlined,
                color: MindSetTheme.info,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'How this text was read',
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Typing behaviour is a tentative aggregate signal, not a diagnosis.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _TypingSourceTile(
            title: 'Typing pattern',
            subtitle: 'Pace, pauses, corrections, and edit rhythm',
            label: typing.label,
            confidence: typing.confidencePercent,
            icon: Icons.keyboard_alt_outlined,
            color: MindSetTheme.info,
            detail: typing.reasons.join(' • '),
          ),
          const SizedBox(height: 10),
          _TypingSourceTile(
            title: 'Text emotion AI',
            subtitle: 'From the words in this reflection',
            label: text.label,
            confidence: text.confidencePercent,
            icon: Icons.notes_rounded,
            color: MindSetTheme.success,
            detail: text.summary,
          ),
          const SizedBox(height: 10),
          _TypingSourceTile(
            title: 'Fused prediction',
            subtitle: 'Confidence-weighted final result',
            label: fused.label,
            confidence: fused.confidencePercent,
            icon: Icons.auto_awesome_rounded,
            color: theme.colorScheme.primary,
            detail: fusionReason,
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _TypingSourceTile extends StatelessWidget {
  const _TypingSourceTile({
    required this.title,
    required this.subtitle,
    required this.label,
    required this.confidence,
    required this.icon,
    required this.color,
    required this.detail,
    this.emphasized = false,
  });
  final String title, subtitle, label, detail;
  final double confidence;
  final IconData icon;
  final Color color;
  final bool emphasized;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      color: emphasized ? color.withValues(alpha: .07) : null,
      border: Border.all(
        color: emphasized
            ? color.withValues(alpha: .55)
            : Theme.of(context).dividerColor,
        width: emphasized ? 1.4 : 1,
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconBox(icon: icon, color: color, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(
                '$label • ${confidence.toStringAsFixed(0)}% confidence',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              if (detail.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  detail,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
