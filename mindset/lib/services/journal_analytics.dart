import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/mindset_theme.dart';

class JournalAnalytics {
  const JournalAnalytics(this.entries);

  final List<JournalEntry> entries;

  List<JournalEntry> get analyzedEntries =>
      entries.where((entry) => entry.result != null).toList();

  int get totalEntries => entries.length;
  int get totalAnalyzed => analyzedEntries.length;

  int get currentStreak {
    final days = entries
        .map((entry) => entry.createdAt)
        .whereType<DateTime>()
        .map(_dateOnly)
        .toSet();
    if (days.isEmpty) {
      return 0;
    }

    var cursor = _dateOnly(DateTime.now());
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  String get mostCommonEmotion {
    final counts = _emotionCounts;
    if (counts.isEmpty) {
      return 'None yet';
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String get highestStressWindow {
    final stressful = <String, int>{};
    for (final entry in analyzedEntries) {
      final date = entry.createdAt;
      final label = entry.result?.label.toLowerCase() ?? '';
      final negative = entry.result?.valence.negativePercent ?? 0;
      if (date == null || (negative < 45 && !_stressLabels.contains(label))) {
        continue;
      }
      final window = '${_weekdayShort(date)} ${date.hour < 12 ? 'AM' : 'PM'}';
      stressful[window] = (stressful[window] ?? 0) + 1;
    }
    if (stressful.isEmpty) {
      return 'No stress pattern yet';
    }
    return stressful.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  int get supportActionsUsed {
    final pattern = RegExp(
      r'\b(help|plan|walk|rest|breathe|break|talk|sleep|ask|journal|meditat|support)\b',
      caseSensitive: false,
    );
    return entries.where((entry) => pattern.hasMatch(entry.text)).length;
  }

  ValenceScore get averageValence {
    final results = analyzedEntries
        .map((entry) => entry.result)
        .whereType<EmotionResult>()
        .toList();
    if (results.isEmpty) {
      return const ValenceScore(
        positive: 0,
        negative: 0,
        neutral: 0,
        positivePercent: 0,
        negativePercent: 0,
        neutralPercent: 0,
      );
    }

    final positive =
        results.fold<double>(0, (sum, item) => sum + item.valence.positivePercent) /
        results.length;
    final negative =
        results.fold<double>(0, (sum, item) => sum + item.valence.negativePercent) /
        results.length;
    final neutral =
        results.fold<double>(0, (sum, item) => sum + item.valence.neutralPercent) /
        results.length;
    return ValenceScore(
      positive: positive / 100,
      negative: negative / 100,
      neutral: neutral / 100,
      positivePercent: positive,
      negativePercent: negative,
      neutralPercent: neutral,
    );
  }

  double get positiveBalance => averageValence.positivePercent;

  List<WeeklyMoodItem> get topEmotions {
    final counts = _emotionCounts;
    if (counts.isEmpty) {
      return const [];
    }

    final total = counts.values.fold<int>(0, (sum, value) => sum + value);
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).map((item) {
      return WeeklyMoodItem(
        label: item.key,
        value: item.value / total,
        color: colorForEmotion(item.key),
      );
    }).toList();
  }

  List<WeeklyMoodItem> get monthlyEntries {
    final counts = <String, int>{};
    for (final entry in entries) {
      final date = entry.createdAt;
      if (date == null) {
        continue;
      }
      final key = _monthLabel(date);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    if (counts.isEmpty) {
      return const [];
    }

    final maxCount = counts.values.reduce((a, b) => a > b ? a : b);
    return counts.entries.map((item) {
      return WeeklyMoodItem(
        label: item.key,
        value: maxCount == 0 ? 0 : item.value / maxCount,
        color: MindSetTheme.info,
      );
    }).toList();
  }

  List<String> get reportNotes {
    if (entries.isEmpty) {
      return const [
        'Save analyzed reflections to generate a report from your own data.',
        'Monthly and emotional trends will update as your journal history grows.',
        'Recommended next steps will use the balance in your saved reflections.',
      ];
    }

    final valence = averageValence;
    final latest =
        entries.first.result?.summary ?? 'Your latest saved reflection is ready to revisit.';
    final trend = valence.positivePercent >= valence.negativePercent
        ? 'Average balance: '
        : 'Average balance: ';
    final recommendation = valence.negativePercent > valence.positivePercent
        ? 'Choose one small support action before the next check-in.'
        : 'Repeat one action that helped your recent emotional tone.';

    return [
      latest,
      '$trend ${valence.positivePercent.toStringAsFixed(0)}% positive, ${valence.negativePercent.toStringAsFixed(0)}% negative, ${valence.neutralPercent.toStringAsFixed(0)}% neutral.',
      recommendation,
    ];
  }

  String exportReportText() {
    final valence = averageValence;
    final notes = reportNotes;
    return [
      'MindSet report',
      'Generated: ${_formatFullDate(DateTime.now())}',
      '',
      'Entries saved: $totalEntries',
      'Entries analyzed: $totalAnalyzed',
      'Most frequent emotion: $mostCommonEmotion',
      'Current streak: $currentStreak ${currentStreak == 1 ? 'day' : 'days'}',
      'Highest stress window: $highestStressWindow',
      'Support actions noticed: $supportActionsUsed',
      'Average valence: ${valence.positivePercent.toStringAsFixed(0)}% positive, ${valence.negativePercent.toStringAsFixed(0)}% negative, ${valence.neutralPercent.toStringAsFixed(0)}% neutral',
      '',
      'Notes:',
      for (final note in notes) '- $note',
    ].join('\n');
  }

  Map<String, int> get _emotionCounts {
    final counts = <String, int>{};
    for (final entry in analyzedEntries) {
      final label = entry.result?.label;
      if (label == null || label.isEmpty) {
        continue;
      }
      counts[label] = (counts[label] ?? 0) + 1;
    }
    return counts;
  }
}

Color colorForEmotion(String emotion) {
  final normalized = emotion.toLowerCase();
  if ([
    'admiration',
    'anticipation',
    'awe',
    'contentment',
    'empathy',
    'excitement',
    'happy',
    'hope',
    'joy',
    'love',
    'pride',
    'relief',
    'trust',
  ].contains(normalized)) {
    return MoodPalette.happy;
  }
  if (['anger', 'angry', 'disgust', 'frustration'].contains(normalized)) {
    return MoodPalette.angry;
  }
  if (['anxiety', 'fear', 'stress'].contains(normalized)) {
    return MoodPalette.stress;
  }
  if ([
    'grief',
    'guilt',
    'jealousy',
    'loneliness',
    'regret',
    'sadness',
    'sad',
    'shame',
  ].contains(normalized)) {
    return MoodPalette.sad;
  }
  return MoodPalette.neutral;
}

IconData iconForEmotion(String emotion) {
  final normalized = emotion.toLowerCase();
  if (['anger', 'angry', 'frustration'].contains(normalized)) {
    return Icons.sentiment_very_dissatisfied;
  }
  if (['anxiety', 'fear', 'stress'].contains(normalized)) {
    return Icons.psychology_outlined;
  }
  if ([
    'sadness',
    'sad',
    'grief',
    'loneliness',
    'regret',
    'shame',
  ].contains(normalized)) {
    return Icons.sentiment_dissatisfied;
  }
  if (['none yet'].contains(normalized)) {
    return Icons.hourglass_empty;
  }
  if (colorForEmotion(emotion) == MoodPalette.happy) {
    return Icons.sentiment_very_satisfied;
  }
  return Icons.sentiment_neutral;
}

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

String _weekdayShort(DateTime value) {
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return labels[value.weekday - 1];
}

String _monthLabel(DateTime value) {
  const labels = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${labels[value.month - 1]} ${value.year}';
}

String _formatFullDate(DateTime value) {
  const labels = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${labels[value.month - 1]} ${value.day}, ${value.year}';
}

const _stressLabels = {
  'anger',
  'anxiety',
  'fear',
  'frustration',
  'stress',
  'sadness',
  'shame',
};
