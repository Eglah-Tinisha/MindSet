import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/journal_analytics.dart';
import '../theme/mindset_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/insight_widgets.dart';

class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key, required this.entries});

  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final analytics = JournalAnalytics(entries);
    final moodData = analytics.topEmotions;
    final valence = analytics.averageValence;

    return ScrollToTopOverlay(
      builder: (scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          PageTitle(
            title: 'Insights',
            subtitle: entries.isEmpty
                ? 'Save reflections to unlock patterns.'
                : 'Gentle patterns from ${entries.length} saved reflections.',
          ),
          const SizedBox(height: 22),
          WellnessCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Emotional balance', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                EmotionProgressRow(
                  label: 'Positive',
                  value: valence.positivePercent / 100,
                  color: MoodPalette.happy,
                ),
                const SizedBox(height: 14),
                EmotionProgressRow(
                  label: 'Negative',
                  value: valence.negativePercent / 100,
                  color: MoodPalette.angry,
                ),
                const SizedBox(height: 14),
                EmotionProgressRow(
                  label: 'Neutral',
                  value: valence.neutralPercent / 100,
                  color: MoodPalette.neutral,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Top emotions'),
          if (moodData.isEmpty)
            WellnessCard(
              child: Text(
                'No emotion data yet. Analyze and save a journal entry first.',
                style: theme.textTheme.bodyLarge,
              ),
            )
          else
            WellnessCard(
              child: Column(
                children: [
                  for (final item in moodData) ...[
                    EmotionProgressRow(
                      label: item.label,
                      value: item.value,
                      color: item.color,
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 18),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Noticed patterns'),
          for (final pattern in _patterns(entries, valence)) ...[
            InsightCard(
              icon: pattern.icon,
              title: pattern.title,
              text: pattern.text,
              color: pattern.color,
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 18),
          const SectionHeader(title: 'Reflection prompt'),
          PromptCard(prompt: _prompt(entries, valence)),
        ],
      ),
    );
  }
}

List<_Pattern> _patterns(List<JournalEntry> entries, ValenceScore valence) {
  if (entries.isEmpty) {
    return const [
      _Pattern(
        icon: Icons.auto_stories_outlined,
        title: 'No patterns yet',
        text:
            'Saved analyzed journals will create your personal insight cards.',
        color: MindSetTheme.info,
      ),
    ];
  }

  final latest = entries.first.result?.label ?? 'your latest emotion';
  return [
    _Pattern(
      icon: Icons.history_toggle_off,
      title: 'Latest signal: $latest',
      text:
          entries.first.result?.summary ??
          'Your latest reflection is saved and ready to review.',
      color: colorForEmotion(latest),
    ),
    _Pattern(
      icon: Icons.balance_outlined,
      title: valence.positivePercent >= valence.negativePercent
          ? 'Positive tone is stronger'
          : 'Difficult tone is stronger',
      text:
          'Average balance is ${valence.positivePercent.toStringAsFixed(0)}% positive, ${valence.negativePercent.toStringAsFixed(0)}% negative, and ${valence.neutralPercent.toStringAsFixed(0)}% neutral.',
      color: valence.positivePercent >= valence.negativePercent
          ? MindSetTheme.success
          : MindSetTheme.warning,
    ),
  ];
}

String _prompt(List<JournalEntry> entries, ValenceScore valence) {
  if (entries.isEmpty) {
    return 'What feeling would be worth understanding today?';
  }
  if (valence.negativePercent > valence.positivePercent) {
    return 'What is one small support action that could make today feel less heavy?';
  }
  return 'What helped your emotional tone improve, and how can you repeat a small part of it?';
}

class _Pattern {
  const _Pattern({
    required this.icon,
    required this.title,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color color;
}
