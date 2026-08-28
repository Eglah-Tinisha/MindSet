import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/journal_analytics.dart';
import '../theme/mindset_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/journal_widgets.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.entries,
    required this.onStartJournal,
    required this.onViewInsights,
    required this.onViewReports,
    required this.onViewSaved,
    required this.onOpenEntry,
  });

  final List<JournalEntry> entries;
  final VoidCallback onStartJournal;
  final VoidCallback onViewInsights;
  final VoidCallback onViewReports;
  final VoidCallback onViewSaved;
  final ValueChanged<JournalEntry> onOpenEntry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final analytics = JournalAnalytics(entries);
    final recentEntries = entries.take(3).toList();
    final commonMood = analytics.mostCommonEmotion;
    final username = _profileName(FirebaseAuth.instance.currentUser);

    return ScrollToTopOverlay(
      builder: (scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Row(
            children: [
              const BrandMark(size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Text('MindSet', style: theme.textTheme.headlineMedium),
              ),
              IconButton.filledTonal(
                tooltip: 'Write reflection',
                onPressed: onStartJournal,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Good to see you, $username',
            style: theme.textTheme.displayLarge,
          ),
          const SizedBox(height: 8),
          Text(
            entries.isEmpty
                ? 'Start with one reflection and your personal patterns will appear here.'
                : 'Here is a calm snapshot from your saved reflections.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 22),
          WellnessCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconBox(
                      icon: Icons.self_improvement,
                      color: MindSetTheme.success,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Most common emotion',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    MoodBadge(
                      label: commonMood,
                      icon: iconForEmotion(commonMood),
                      color: colorForEmotion(commonMood),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _homeSummary(entries, commonMood),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onStartJournal,
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Write today'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 620 ? 3 : 1;
              return GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: columns == 1 ? 4.3 : 2.7,
                ),
                children: [
                  StatTile(
                    label: 'Saved reflections',
                    value: '${entries.length}',
                    icon: Icons.article_outlined,
                    color: MindSetTheme.info,
                    onTap: onViewSaved,
                  ),
                  StatTile(
                    label: 'Positive balance',
                    value: '${analytics.positiveBalance.round()}%',
                    icon: Icons.spa_outlined,
                    color: MindSetTheme.success,
                    onTap: onViewInsights,
                  ),
                  StatTile(
                    label: 'Current streak',
                    value:
                        '${analytics.currentStreak} ${analytics.currentStreak == 1 ? 'day' : 'days'}',
                    icon: Icons.local_fire_department_outlined,
                    color: MindSetTheme.warning,
                    onTap: onViewReports,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          SectionHeader(
            title: 'Recent reflections',
            action: TextButton(
              onPressed: onViewSaved,
              child: const Text('View all'),
            ),
          ),
          if (recentEntries.isEmpty)
            WellnessCard(
              child: Text(
                'No saved journals yet. Analyze a reflection and save it to build your history.',
                style: theme.textTheme.bodyLarge,
              ),
            )
          else
            for (final entry in recentEntries) ...[
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onOpenEntry(entry),
                child: JournalEntryCard(entry: entry),
              ),
              const SizedBox(height: 12),
            ],
          SectionHeader(
            title: 'Next step',
            action: TextButton(
              onPressed: onViewInsights,
              child: const Text('Insights'),
            ),
          ),
          WellnessCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IconBox(icon: Icons.psychology_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _nextStep(entries),
                    style: theme.textTheme.bodyLarge,
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

String _homeSummary(List<JournalEntry> entries, String mood) {
  if (entries.isEmpty) {
    return 'Your dashboard will update after you save analyzed journal entries.';
  }
  return '$mood appears most often in your saved history. Open Insights for the full breakdown.';
}

String _nextStep(List<JournalEntry> entries) {
  if (entries.isEmpty) {
    return 'Write one honest entry today. The app will save the emotion result so you can revisit it later.';
  }
  final latest = entries.first.result?.summary;
  if (latest == null || latest.isEmpty) {
    return 'Review your latest entry and notice one support action you can take next.';
  }
  return latest;
}

String _profileName(User? user) {
  final displayName = user?.displayName?.trim();
  if (displayName != null && displayName.isNotEmpty) {
    return displayName;
  }
  final email = user?.email ?? '';
  if (email.contains('@')) {
    return email.split('@').first;
  }
  return 'User';
}
