import 'dart:math' as math;

import '../models/models.dart';

/// Collects private aggregate edit behaviour for one text-journal session.
/// It never stores raw keystrokes, typed fragments, or an edit timeline.
class TypingBehaviorTracker {
  String _previousText = '';
  DateTime? _startedAt;
  DateTime? _lastEditAt;
  DateTime? _lastDeletionAt;
  int _inserted = 0;
  int _deleted = 0;
  int _corrections = 0;
  int _deletionBursts = 0;
  int _pauses = 0;
  int _longPauses = 0;
  int _repeatedCharacters = 0;
  int _repeatedPunctuation = 0;
  int _repeatedSpaces = 0;
  int _keyboardSmashes = 0;
  int _longestPauseMs = 0;
  final List<int> _intervals = [];

  void reset({String initialText = ''}) {
    _previousText = initialText;
    _startedAt = null;
    _lastEditAt = null;
    _lastDeletionAt = null;
    _inserted = 0;
    _deleted = 0;
    _corrections = 0;
    _deletionBursts = 0;
    _pauses = 0;
    _longPauses = 0;
    _repeatedCharacters = 0;
    _repeatedPunctuation = 0;
    _repeatedSpaces = 0;
    _keyboardSmashes = 0;
    _longestPauseMs = 0;
    _intervals.clear();
  }

  void recordText(String nextText, {DateTime? at}) {
    final now = at ?? DateTime.now();
    if (nextText == _previousText) return;

    _startedAt ??= now;
    final previousEdit = _lastEditAt;
    if (previousEdit != null) {
      final interval = now.difference(previousEdit).inMilliseconds;
      if (interval >= 800) {
        _pauses++;
        if (interval >= 3000) _longPauses++;
        _longestPauseMs = math.max(_longestPauseMs, interval);
      }
      if (interval <= 10000) _intervals.add(interval);
    }

    final delta = _TextDelta.between(_previousText, nextText);

    if (delta.deleted > 0) {
      _deleted += delta.deleted;
      if (_lastDeletionAt == null ||
          now.difference(_lastDeletionAt!).inMilliseconds > 900) {
        _deletionBursts++;
      }
      if (delta.deleted >= 12) _deletionBursts++;
      _lastDeletionAt = now;
    }

    if (delta.insertedText.isNotEmpty) {
      _inserted += delta.insertedText.length;
      _inspectInsertedText(delta.insertedText);

      final deletedAt = _lastDeletionAt;
      if (deletedAt != null &&
          now.difference(deletedAt).inMilliseconds <= 2000) {
        _corrections++;
        _lastDeletionAt = null;
      }
    }

    _previousText = nextText;
    _lastEditAt = now;
  }

  void _inspectInsertedText(String text) {
    if (RegExp(r'(.)\1{2,}').hasMatch(text)) {
      _repeatedCharacters++;
    }
    if (RegExp(r'[!?.]{3,}').hasMatch(text)) {
      _repeatedPunctuation++;
    }
    if (RegExp(r' {3,}').hasMatch(text)) {
      _repeatedSpaces++;
    }
    if (RegExp(
      r'(asdf|qwer|zxcv|1234|4321|poi|lkj)',
      caseSensitive: false,
    ).hasMatch(text)) {
      _keyboardSmashes++;
    }
  }

  TypingBehaviorMetrics snapshot({DateTime? at}) {
    final now = at ?? DateTime.now();

    final seconds = _startedAt == null
        ? 0.0
        : math.max(0.0, now.difference(_startedAt!).inMilliseconds / 1000.0);

    final activeSeconds = seconds <= 0 ? 0.0 : seconds;
    final cps = activeSeconds == 0 ? 0.0 : _inserted / activeSeconds;

    final mean = _intervals.isEmpty
        ? 0.0
        : _intervals.reduce((a, b) => a + b) / _intervals.length;

    final variance = _intervals.isEmpty
        ? 0.0
        : _intervals
                  .map((value) => math.pow(value - mean, 2))
                  .reduce((a, b) => a + b) /
              _intervals.length;

    return TypingBehaviorMetrics(
      insertedCharacters: _inserted,
      deletedCharacters: _deleted,
      correctionCount: _corrections,
      deletionBursts: _deletionBursts,
      pauseCount: _pauses,
      longPauseCount: _longPauses,
      repeatedCharacterCount: _repeatedCharacters,
      repeatedPunctuationCount: _repeatedPunctuation,
      repeatedSpaceCount: _repeatedSpaces,
      keyboardSmashCount: _keyboardSmashes,
      activeSeconds: activeSeconds,
      charactersPerSecond: cps,
      intervalVariance: variance.sqrt(),
      rewriteRatio: _inserted == 0 ? 0.0 : _deleted / _inserted,
      longestPauseMilliseconds: _longestPauseMs,
    );
  }
}

class TypingFusionOutcome {
  const TypingFusionOutcome({required this.result, required this.reason});

  final EmotionResult result;
  final String reason;
}

/// Explainable prototype scoring. This is a tentative behavioural signal,
/// not a diagnosis and not a trained clinical emotion classifier.
class TypingBehaviorAnalyzer {
  static const minimumCharacters = 30;
  static const minimumActiveSeconds = 8.0;

  TypingBehaviorResult? analyze(TypingBehaviorMetrics metrics) {
    if (metrics.insertedCharacters < minimumCharacters ||
        metrics.activeSeconds < minimumActiveSeconds) {
      return null;
    }

    final speed = metrics.charactersPerSecond;

    final correctionRatio = metrics.insertedCharacters == 0
        ? 0.0
        : metrics.deletedCharacters / metrics.insertedCharacters;

    final irregular = metrics.intervalVariance >= 650;
    final slow = speed < 0.45;
    final fast = speed > 1.35;

    final scores = <String, double>{
      'Anxiety': ((fast ? 2 : 0) + correctionRatio * 8 + (irregular ? 2 : 0))
          .toDouble(),
      'Stress':
          (metrics.keyboardSmashCount * 3 +
                  metrics.repeatedSpaceCount * 2 +
                  metrics.deletionBursts * .7 +
                  metrics.longPauseCount)
              .toDouble(),
      'Anger':
          ((fast ? 1.5 : 0) +
                  metrics.repeatedPunctuationCount * 2 +
                  metrics.repeatedCharacterCount)
              .toDouble(),
      'Frustration':
          (metrics.rewriteRatio * 6 +
                  metrics.deletionBursts +
                  metrics.repeatedPunctuationCount)
              .toDouble(),
      'Sadness':
          ((slow ? 2 : 0) +
                  metrics.longPauseCount * 1.2 +
                  (correctionRatio < .08 ? .5 : 0))
              .toDouble(),
      'Fatigue': ((slow ? 2 : 0) + correctionRatio * 4 + metrics.longPauseCount)
          .toDouble(),
      'Confusion':
          (metrics.pauseCount * .5 +
                  metrics.deletionBursts +
                  correctionRatio * 5 +
                  (irregular ? 1 : 0))
              .toDouble(),
      'Nervousness':
          ((irregular ? 2 : 0) + correctionRatio * 5 + metrics.pauseCount * .35)
              .toDouble(),
      'Excitement':
          ((fast ? 2 : 0) +
                  metrics.repeatedPunctuationCount * 2 +
                  metrics.repeatedCharacterCount)
              .toDouble(),
      'Calm':
          ((!irregular ? 2 : 0) +
                  (correctionRatio < .08 ? 1.5 : 0) +
                  (speed >= .45 && speed <= 1.35 ? 1 : 0))
              .toDouble(),
      'Focused':
          ((!irregular ? 2.2 : 0) +
                  (correctionRatio < .06 ? 1.5 : 0) +
                  (metrics.pauseCount <= 2 ? 1 : 0))
              .toDouble(),
      'Boredom':
          ((slow ? 1.8 : 0) +
                  metrics.longPauseCount * 1.2 +
                  (metrics.repeatedCharacterCount > 0 ? .5 : 0))
              .toDouble(),
    };

    final ordered = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final winner = ordered.first;
    final runnerUp = ordered.length > 1 ? ordered[1].value : 0.0;

    final confidence =
        ((winner.value / 8) * 70 +
                ((winner.value - runnerUp).clamp(0, 3) / 3) * 30)
            .clamp(20.0, 92.0);

    final reasons = _reasons(
      metrics,
      fast: fast,
      slow: slow,
      irregular: irregular,
      correctionRatio: correctionRatio,
    );

    return TypingBehaviorResult(
      label: winner.key,
      mappedEmotion: _mappedEmotion(winner.key),
      confidencePercent: confidence,
      summary:
          'This is a tentative typing-pattern signal based on aggregate editing behaviour, not a diagnosis.',
      reasons: reasons,
      metrics: metrics,
    );
  }

  /// Combines both sources before selecting the final label.
  ///
  /// Text top-emotion probabilities are normalized and weighted by text
  /// reliability. The mapped typing-pattern signal is added using its own
  /// reliability. The final emotion is selected from those combined scores.
  TypingFusionOutcome fuse({
    required EmotionResult textResult,
    required TypingBehaviorResult typingResult,
  }) {
    final textReliability = math.max(.25, textResult.confidencePercent / 100);

    final typingReliability = math.max(
      .25,
      typingResult.confidencePercent / 100,
    );

    final totalReliability = textReliability + typingReliability;

    final textContribution = textReliability / totalReliability * 100;
    final typingContribution = typingReliability / totalReliability * 100;

    final textScores = <String, double>{};

    for (final item in textResult.topEmotions) {
      textScores[item.emotion.toLowerCase()] = item.confidence;
    }

    textScores.putIfAbsent(
      textResult.rawEmotion.toLowerCase(),
      () => textResult.confidencePercent / 100,
    );

    final textTotal = textScores.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );

    final combined = <String, double>{};

    if (textTotal > 0) {
      textScores.forEach((emotion, probability) {
        combined[emotion] = (probability / textTotal) * textReliability;
      });
    }

    final mappedTypingEmotion = typingResult.mappedEmotion;

    combined[mappedTypingEmotion] =
        (combined[mappedTypingEmotion] ?? 0) + typingReliability;

    final ranked = combined.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final winner = ranked.first;

    final fusedPercent = (winner.value / totalReliability * 100).clamp(
      0.0,
      100.0,
    );

    final winnerFromText = textScores.containsKey(winner.key);

    final reason =
        'Combined from your words and aggregate typing behaviour. '
        'Text contribution: ${textContribution.toStringAsFixed(0)}%. '
        'Typing-pattern contribution: '
        '${typingContribution.toStringAsFixed(0)}%. '
        '${winnerFromText ? 'The final emotion also appeared in the text signal.' : 'The typing-pattern mapping added a new emotion candidate.'}';

    return TypingFusionOutcome(
      reason: reason,
      result: EmotionResult(
        label: _titleCase(winner.key),
        rawEmotion: winner.key,
        icon: textResult.icon,
        color: textResult.color,
        confidence: fusedPercent.round(),
        confidencePercent: fusedPercent,
        confidenceLabel: _confidenceLabel(fusedPercent),
        certaintyScore: textResult.certaintyScore,
        entropy: textResult.entropy,
        mirrorStatement: textResult.mirrorStatement,
        summary: textResult.summary,
        tags: textResult.tags,
        topEmotions: textResult.topEmotions,
        valence: textResult.valence,
      ),
    );
  }

  List<String> _reasons(
    TypingBehaviorMetrics metrics, {
    required bool fast,
    required bool slow,
    required bool irregular,
    required double correctionRatio,
  }) {
    final reasons = <String>[];

    if (fast) {
      reasons.add('faster typing pace');
    }

    if (slow) {
      reasons.add('slower typing pace');
    }

    if (irregular) {
      reasons.add('irregular timing between edits');
    }

    if (correctionRatio >= .12) {
      reasons.add('frequent deletions or corrections');
    }

    if (metrics.longPauseCount > 0) {
      reasons.add('long pauses while writing');
    }

    if (metrics.deletionBursts > 1) {
      reasons.add('bursts of deletion or rewriting');
    }

    if (metrics.repeatedPunctuationCount > 0 ||
        metrics.repeatedCharacterCount > 0) {
      reasons.add('repeated characters or punctuation');
    }

    if (metrics.keyboardSmashCount > 0) {
      reasons.add('keyboard-pattern bursts');
    }

    return reasons.isEmpty
        ? const ['steady aggregate typing behaviour']
        : reasons.take(3).toList();
  }

  String _mappedEmotion(String label) => switch (label) {
    'Anxiety' || 'Stress' || 'Nervousness' => 'anxiety',
    'Anger' => 'anger',
    'Frustration' => 'frustration',
    'Sadness' => 'sadness',
    'Fatigue' || 'Boredom' => 'boredom',
    'Confusion' => 'confusion',
    'Excitement' => 'excitement',
    'Calm' || 'Focused' => 'contentment',
    _ => 'unknown',
  };

  String _confidenceLabel(double percent) {
    if (percent >= 75) return 'High';
    if (percent >= 55) return 'Moderate';
    return 'Low';
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

class _TextDelta {
  const _TextDelta({required this.deleted, required this.insertedText});

  final int deleted;
  final String insertedText;

  factory _TextDelta.between(String before, String after) {
    var prefix = 0;

    while (prefix < before.length &&
        prefix < after.length &&
        before[prefix] == after[prefix]) {
      prefix++;
    }

    var suffix = 0;

    while (suffix < before.length - prefix &&
        suffix < after.length - prefix &&
        before[before.length - 1 - suffix] ==
            after[after.length - 1 - suffix]) {
      suffix++;
    }

    return _TextDelta(
      deleted: before.length - prefix - suffix,
      insertedText: after.substring(prefix, after.length - suffix),
    );
  }
}

extension on num {
  double sqrt() => math.sqrt(toDouble());
}
