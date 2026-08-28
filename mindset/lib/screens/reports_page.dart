import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/journal_analytics.dart';
import '../widgets/common_widgets.dart';
import '../widgets/insight_widgets.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key, required this.entries});

  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final analytics = JournalAnalytics(entries);
    final notes = analytics.reportNotes;
    return ScrollToTopOverlay(
      builder: (scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          PageTitle(
            title: 'Reports',
            subtitle: entries.isEmpty
                ? 'Save reflections to generate a real report.'
                : 'A report generated from ${entries.length} saved ${entries.length == 1 ? 'reflection' : 'reflections'}.',
          ),
          const SizedBox(height: 22),
          WellnessCard(
            child: Column(
              children: [
                ReportMetricRow(
                  label: 'Entries saved',
                  value: '${analytics.totalEntries}',
                ),
                const Divider(height: 1),
                ReportMetricRow(
                  label: 'Entries analyzed',
                  value: '${analytics.totalAnalyzed}',
                ),
                const Divider(height: 1),
                ReportMetricRow(
                  label: 'Most frequent emotion',
                  value: analytics.mostCommonEmotion,
                ),
                const Divider(height: 1),
                ReportMetricRow(
                  label: 'Highest stress window',
                  value: analytics.highestStressWindow,
                ),
                const Divider(height: 1),
                ReportMetricRow(
                  label: 'Support actions noticed',
                  value: '${analytics.supportActionsUsed}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Report notes'),
          ReportSectionCard(
            icon: Icons.trending_up_outlined,
            title: 'Latest signal',
            body: notes[0],
          ),
          const SizedBox(height: 12),
          ReportSectionCard(
            icon: Icons.warning_amber_outlined,
            title: 'Mood trend',
            body: notes[1],
          ),
          const SizedBox(height: 12),
          ReportSectionCard(
            icon: Icons.recommend_outlined,
            title: 'Recommended next step',
            body: notes[2],
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: analytics.exportReportText()),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report copied to clipboard.')),
                );
              }
            },
            icon: const Icon(Icons.download_outlined),
            label: const Text('Copy report'),
          ),
        ],
      ),
    );
  }
}
