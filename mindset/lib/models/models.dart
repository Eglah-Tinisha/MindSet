import 'package:flutter/material.dart';

class EmotionResult {
  const EmotionResult({
    required this.label,
    required this.rawEmotion,
    required this.icon,
    required this.color,
    required this.confidence,
    required this.confidencePercent,
    required this.confidenceLabel,
    required this.certaintyScore,
    required this.entropy,
    required this.mirrorStatement,
    required this.summary,
    required this.tags,
    required this.topEmotions,
    required this.valence,
  });

  final String label;
  final String rawEmotion;
  final IconData icon;
  final Color color;
  final int confidence;
  final double confidencePercent;
  final String confidenceLabel;
  final double certaintyScore;
  final double entropy;
  final String mirrorStatement;
  final String summary;
  final List<String> tags;
  final List<EmotionScore> topEmotions;
  final ValenceScore valence;

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'rawEmotion': rawEmotion,
      'icon': icon.codePoint,
      'color': color.toARGB32(),
      'confidence': confidence,
      'confidencePercent': confidencePercent,
      'confidenceLabel': confidenceLabel,
      'certaintyScore': certaintyScore,
      'entropy': entropy,
      'mirrorStatement': mirrorStatement,
      'summary': summary,
      'tags': tags,
      'topEmotions': topEmotions.map((item) => item.toJson()).toList(),
      'valence': valence.toJson(),
    };
  }

  factory EmotionResult.fromJson(Map<String, dynamic> json) {
    return EmotionResult(
      label: json['label']?.toString() ?? 'Unknown',
      rawEmotion: json['rawEmotion']?.toString() ?? 'unknown',
      icon: IconData(
        // ignore: non_const_argument_for_const_parameter
        _asInt(json['icon'], Icons.sentiment_neutral.codePoint),
        fontFamily: 'MaterialIcons',
      ),
      color: Color(_asInt(json['color'], Colors.grey.toARGB32())),
      confidence: _asDouble(json['confidence']).round(),
      confidencePercent: _asDouble(json['confidencePercent']),
      confidenceLabel: json['confidenceLabel']?.toString() ?? 'Unknown',
      certaintyScore: _asDouble(json['certaintyScore']),
      entropy: _asDouble(json['entropy']),
      mirrorStatement: json['mirrorStatement']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      tags: (json['tags'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      topEmotions: (json['topEmotions'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => EmotionScore.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      valence: ValenceScore.fromJson(
        Map<String, dynamic>.from(json['valence'] as Map? ?? const {}),
      ),
    );
  }
}

class EmotionScore {
  const EmotionScore({
    required this.emotion,
    required this.confidence,
    required this.confidencePercent,
  });

  final String emotion;
  final double confidence;
  final double confidencePercent;

  Map<String, dynamic> toJson() {
    return {
      'emotion': emotion,
      'confidence': confidence,
      'confidencePercent': confidencePercent,
    };
  }

  factory EmotionScore.fromJson(Map<String, dynamic> json) {
    return EmotionScore(
      emotion: json['emotion']?.toString() ?? 'Unknown',
      confidence: _asDouble(json['confidence']),
      confidencePercent: _asDouble(json['confidencePercent']),
    );
  }
}

class ValenceScore {
  const ValenceScore({
    required this.positive,
    required this.negative,
    required this.neutral,
    required this.positivePercent,
    required this.negativePercent,
    required this.neutralPercent,
  });

  final double positive;
  final double negative;
  final double neutral;
  final double positivePercent;
  final double negativePercent;
  final double neutralPercent;

  Map<String, dynamic> toJson() {
    return {
      'positive': positive,
      'negative': negative,
      'neutral': neutral,
      'positivePercent': positivePercent,
      'negativePercent': negativePercent,
      'neutralPercent': neutralPercent,
    };
  }

  factory ValenceScore.fromJson(Map<String, dynamic> json) {
    return ValenceScore(
      positive: _asDouble(json['positive']),
      negative: _asDouble(json['negative']),
      neutral: _asDouble(json['neutral']),
      positivePercent: _asDouble(json['positivePercent']),
      negativePercent: _asDouble(json['negativePercent']),
      neutralPercent: _asDouble(json['neutralPercent']),
    );
  }
}

/// Aggregate typing behaviour only. No raw keystrokes, text fragments, or
/// individual key timestamps are stored in this model.
class TypingBehaviorMetrics {
  const TypingBehaviorMetrics({
    required this.insertedCharacters,
    required this.deletedCharacters,
    required this.correctionCount,
    required this.deletionBursts,
    required this.pauseCount,
    required this.longPauseCount,
    required this.repeatedCharacterCount,
    required this.repeatedPunctuationCount,
    required this.repeatedSpaceCount,
    required this.keyboardSmashCount,
    required this.activeSeconds,
    required this.charactersPerSecond,
    required this.intervalVariance,
    required this.rewriteRatio,
    required this.longestPauseMilliseconds,
  });

  final int insertedCharacters;
  final int deletedCharacters;
  final int correctionCount;
  final int deletionBursts;
  final int pauseCount;
  final int longPauseCount;
  final int repeatedCharacterCount;
  final int repeatedPunctuationCount;
  final int repeatedSpaceCount;
  final int keyboardSmashCount;
  final double activeSeconds;
  final double charactersPerSecond;
  final double intervalVariance;
  final double rewriteRatio;
  final int longestPauseMilliseconds;

  Map<String, dynamic> toJson() => {
    'insertedCharacters': insertedCharacters,
    'deletedCharacters': deletedCharacters,
    'correctionCount': correctionCount,
    'deletionBursts': deletionBursts,
    'pauseCount': pauseCount,
    'longPauseCount': longPauseCount,
    'repeatedCharacterCount': repeatedCharacterCount,
    'repeatedPunctuationCount': repeatedPunctuationCount,
    'repeatedSpaceCount': repeatedSpaceCount,
    'keyboardSmashCount': keyboardSmashCount,
    'activeSeconds': activeSeconds,
    'charactersPerSecond': charactersPerSecond,
    'intervalVariance': intervalVariance,
    'rewriteRatio': rewriteRatio,
    'longestPauseMilliseconds': longestPauseMilliseconds,
  };

  factory TypingBehaviorMetrics.fromJson(Map<String, dynamic> json) =>
      TypingBehaviorMetrics(
        insertedCharacters: _asInt(json['insertedCharacters'], 0),
        deletedCharacters: _asInt(json['deletedCharacters'], 0),
        correctionCount: _asInt(json['correctionCount'], 0),
        deletionBursts: _asInt(json['deletionBursts'], 0),
        pauseCount: _asInt(json['pauseCount'], 0),
        longPauseCount: _asInt(json['longPauseCount'], 0),
        repeatedCharacterCount: _asInt(json['repeatedCharacterCount'], 0),
        repeatedPunctuationCount: _asInt(json['repeatedPunctuationCount'], 0),
        repeatedSpaceCount: _asInt(json['repeatedSpaceCount'], 0),
        keyboardSmashCount: _asInt(json['keyboardSmashCount'], 0),
        activeSeconds: _asDouble(json['activeSeconds']),
        charactersPerSecond: _asDouble(json['charactersPerSecond']),
        intervalVariance: _asDouble(json['intervalVariance']),
        rewriteRatio: _asDouble(json['rewriteRatio']),
        longestPauseMilliseconds: _asInt(json['longestPauseMilliseconds'], 0),
      );
}

/// A tentative, explainable signal calculated from aggregate typing behaviour.
class TypingBehaviorResult {
  const TypingBehaviorResult({
    required this.label,
    required this.mappedEmotion,
    required this.confidencePercent,
    required this.summary,
    required this.reasons,
    required this.metrics,
  });

  final String label;
  final String mappedEmotion;
  final double confidencePercent;
  final String summary;
  final List<String> reasons;
  final TypingBehaviorMetrics metrics;

  Map<String, dynamic> toJson() => {
    'label': label,
    'mappedEmotion': mappedEmotion,
    'confidencePercent': confidencePercent,
    'summary': summary,
    'reasons': reasons,
    'metrics': metrics.toJson(),
  };

  factory TypingBehaviorResult.fromJson(Map<String, dynamic> json) =>
      TypingBehaviorResult(
        label: json['label']?.toString() ?? 'Unknown',
        mappedEmotion: json['mappedEmotion']?.toString() ?? 'unknown',
        confidencePercent: _asDouble(json['confidencePercent']),
        summary: json['summary']?.toString() ?? '',
        reasons: (json['reasons'] as List? ?? const [])
            .map((item) => item.toString())
            .toList(),
        metrics: TypingBehaviorMetrics.fromJson(
          Map<String, dynamic>.from(json['metrics'] as Map? ?? const {}),
        ),
      );
}

class MoodOption {
  const MoodOption({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

class WeeklyMoodItem {
  const WeeklyMoodItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

class JournalEntry {
  const JournalEntry({
    this.id = '',
    this.createdAt,
    this.text = '',
    this.result,
    this.textResult,
    this.audioResult,
    this.typingResult,
    this.fusionReason,
    this.voiceReason,
    this.voiceStrategy,
    this.voicePipeline,
    this.voiceSttOk,
    this.voiceSttMs,
    this.voiceAudioMs,
    this.voiceTextMs,
    this.date = '',
    this.mood = '',
    this.preview = '',
  });

  final String id;
  final DateTime? createdAt;
  final String text;

  /// Final result. For typing-enabled text journals this is the fused result.
  final EmotionResult? result;
  final EmotionResult? textResult;

  /// Voice-tone result, when this entry was created from an audio reflection.
  final EmotionResult? audioResult;
  final TypingBehaviorResult? typingResult;
  final String? fusionReason;
  final String? voiceReason;
  final String? voiceStrategy;
  final Map<String, dynamic>? voicePipeline;
  final bool? voiceSttOk;
  final int? voiceSttMs;
  final int? voiceAudioMs;
  final int? voiceTextMs;
  final String date;
  final String mood;
  final String preview;

  String get displayDate => date.isNotEmpty ? date : _formatDate(createdAt);
  String get displayMood => mood.isNotEmpty ? mood : result?.label ?? 'Unknown';
  String get displayPreview {
    if (preview.isNotEmpty) {
      return preview;
    }
    return text.length <= 150 ? text : '${text.substring(0, 150)}...';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt?.toIso8601String(),
      'text': text,
      'result': result?.toJson(),
      'textResult': textResult?.toJson(),
      'audioResult': audioResult?.toJson(),
      'typingResult': typingResult?.toJson(),
      'fusionReason': fusionReason,
      'voiceReason': voiceReason,
      'voiceStrategy': voiceStrategy,
      'voicePipeline': voicePipeline,
      'voiceSttOk': voiceSttOk,
      'voiceSttMs': voiceSttMs,
      'voiceAudioMs': voiceAudioMs,
      'voiceTextMs': voiceTextMs,
    };
  }

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      text: json['text']?.toString() ?? '',
      result: json['result'] is Map
          ? EmotionResult.fromJson(
              Map<String, dynamic>.from(json['result'] as Map),
            )
          : null,
      textResult: json['textResult'] is Map
          ? EmotionResult.fromJson(
              Map<String, dynamic>.from(json['textResult'] as Map),
            )
          : null,
      audioResult: json['audioResult'] is Map
          ? EmotionResult.fromJson(
              Map<String, dynamic>.from(json['audioResult'] as Map),
            )
          : null,
      typingResult: json['typingResult'] is Map
          ? TypingBehaviorResult.fromJson(
              Map<String, dynamic>.from(json['typingResult'] as Map),
            )
          : null,
      fusionReason: json['fusionReason']?.toString(),
      voiceReason: json['voiceReason']?.toString(),
      voiceStrategy: json['voiceStrategy']?.toString(),
      voicePipeline: json['voicePipeline'] is Map
          ? Map<String, dynamic>.from(json['voicePipeline'] as Map)
          : null,
      voiceSttOk: json['voiceSttOk'] as bool?,
      voiceSttMs: _asNullableInt(json['voiceSttMs']),
      voiceAudioMs: _asNullableInt(json['voiceAudioMs']),
      voiceTextMs: _asNullableInt(json['voiceTextMs']),
    );
  }
}

class FeatureItem {
  const FeatureItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

class AppSettings {
  const AppSettings({
    this.apiEndpoint = 'http://10.0.2.2:8000/predict',
    this.autoSaveEntries = true,
    this.voiceReflection = true,
    this.weeklySummary = true,
    this.typingRhythm = false,
    this.pausePattern = true,
  });

  final String apiEndpoint;
  final bool autoSaveEntries;
  final bool voiceReflection;
  final bool weeklySummary;
  final bool typingRhythm;
  final bool pausePattern;

  /// Base origin for audio/multimodal routes (scheme + host[:port]).
  String get apiBaseUrl {
    final uri = Uri.tryParse(apiEndpoint);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'http://10.0.2.2:8000';
    }
    return uri.origin;
  }

  AppSettings copyWith({
    String? apiEndpoint,
    bool? autoSaveEntries,
    bool? voiceReflection,
    bool? weeklySummary,
    bool? typingRhythm,
    bool? pausePattern,
  }) {
    return AppSettings(
      apiEndpoint: apiEndpoint ?? this.apiEndpoint,
      autoSaveEntries: autoSaveEntries ?? this.autoSaveEntries,
      voiceReflection: voiceReflection ?? this.voiceReflection,
      weeklySummary: weeklySummary ?? this.weeklySummary,
      typingRhythm: typingRhythm ?? this.typingRhythm,
      pausePattern: pausePattern ?? this.pausePattern,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'apiEndpoint': apiEndpoint,
      'autoSaveEntries': autoSaveEntries,
      'voiceReflection': voiceReflection,
      'weeklySummary': weeklySummary,
      'typingRhythm': typingRhythm,
      'pausePattern': pausePattern,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    var endpoint =
        json['apiEndpoint']?.toString() ?? 'http://10.0.2.2:8000/predict';
    // Migrate old default /analyze â†’ /predict (API serves both when updated).
    if (endpoint.endsWith('/analyze')) {
      endpoint =
          '${endpoint.substring(0, endpoint.length - '/analyze'.length)}/predict';
    }
    return AppSettings(
      apiEndpoint: endpoint,
      autoSaveEntries: json['autoSaveEntries'] as bool? ?? true,
      voiceReflection: json['voiceReflection'] as bool? ?? true,
      weeklySummary: json['weeklySummary'] as bool? ?? true,
      typingRhythm: json['typingRhythm'] as bool? ?? false,
      pausePattern: json['pausePattern'] as bool? ?? true,
    );
  }
}

double _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _asInt(Object? value, int fallback) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _asNullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

String _formatDate(DateTime? value) {
  if (value == null) {
    return 'Unknown date';
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(value.year, value.month, value.day);
  final difference = today.difference(date).inDays;

  if (difference == 0) {
    return 'Today';
  }
  if (difference == 1) {
    return 'Yesterday';
  }

  const months = [
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
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}
