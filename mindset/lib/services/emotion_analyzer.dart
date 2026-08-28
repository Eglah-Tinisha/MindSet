import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../theme/mindset_theme.dart';

class EmotionAnalyzerException implements Exception {
  const EmotionAnalyzerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class EmotionAnalyzer {
  EmotionAnalyzer({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      _endpoints = [
        endpoint ?? Uri.parse(_defaultEndpoint),
        for (final fallback in _fallbackEndpoints) Uri.parse(fallback),
      ];

  static const _defaultEndpoint = String.fromEnvironment(
    'EMOTION_API_URL',
    defaultValue: 'http://10.0.2.2:8000/predict',
  );
  static const _fallbackEndpoints = [
    'http://127.0.0.1:8000/predict',
    'http://localhost:8000/predict',
    'http://10.0.2.2:8000/predict',
  ];

  final http.Client _client;
  final List<Uri> _endpoints;

  Future<EmotionResult> analyze(String text) async {
    final cleanedText = text.trim();
    if (cleanedText.isEmpty) {
      throw const EmotionAnalyzerException('Write a reflection first.');
    }

    EmotionAnalyzerException? lastError;

    for (final endpoint in _endpoints) {
      try {
        return await _analyzeWithEndpoint(endpoint, cleanedText);
      } on EmotionAnalyzerException catch (error) {
        lastError = error;
      }
    }

    throw lastError ??
        const EmotionAnalyzerException(
          'Could not reach the local emotion API.',
        );
  }

  Future<EmotionResult> _analyzeWithEndpoint(Uri endpoint, String text) async {
    try {
      final response = await _client
          .post(
            endpoint,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text}),
          )
          .timeout(const Duration(seconds: 60));

      final decoded = _decodeBody(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded['detail']?.toString();
        throw EmotionAnalyzerException(
          detail == null || detail.isEmpty
              ? 'Emotion API returned status ${response.statusCode}.'
              : detail,
        );
      }

      return _resultFromJson(decoded);
    } on TimeoutException {
      throw const EmotionAnalyzerException(
        'The local emotion API took too long to respond.',
      );
    } on http.ClientException catch (error) {
      throw EmotionAnalyzerException(
        'Could not reach the local emotion API at $endpoint. Start Uvicorn and try again. ${error.message}',
      );
    } on FormatException {
      throw const EmotionAnalyzerException(
        'The emotion API returned a response the app could not read.',
      );
    }
  }

  Map<String, dynamic> _decodeBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object.');
    }
    return decoded;
  }

  EmotionResult _resultFromJson(Map<String, dynamic> json) {
    final rawEmotion =
        json['primary_emotion']?.toString() ??
        json['emotion']?.toString() ??
        'neutral';
    final display = _displayEmotion(rawEmotion);
    final primaryProbability = _score01(
      json['primary_prob'] ?? json['confidence'] ?? json['confidence_percent'],
    );
    final confidencePercent = primaryProbability * 100;
    final topEmotions = _topEmotionsFromJson(json['top_emotions']);
    final valence = _valenceFromJson(json['valence']);

    return EmotionResult(
      label: display.label,
      rawEmotion: rawEmotion,
      icon: display.icon,
      color: display.color,
      confidence: confidencePercent.round(),
      confidencePercent: confidencePercent,
      confidenceLabel:
          json['confidence_label']?.toString() ??
          _confidenceLabel(confidencePercent),
      certaintyScore: _asDouble(json['certainty_score']),
      entropy: _asDouble(json['entropy']),
      mirrorStatement: _mirrorStatement(rawEmotion),
      summary:
          json['ai_summary']?.toString() ??
          json['summary']?.toString() ??
          'No summary was returned.',
      tags: topEmotions.map((item) => item.emotion).take(3).toList(),
      topEmotions: topEmotions,
      valence: valence,
    );
  }

  List<EmotionScore> _topEmotionsFromJson(Object? value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map((item) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            final probability = _score01(
              map['prob'] ??
                  map['probability'] ??
                  map['score'] ??
                  map['confidence'],
            );
            return EmotionScore(
              emotion: _titleCase(
                map['emotion']?.toString() ??
                    map['label']?.toString() ??
                    map['name']?.toString() ??
                    'unknown',
              ),
              confidence: probability,
              confidencePercent: _asDouble(map['confidence_percent']) == 0
                  ? probability * 100
                  : _asDouble(map['confidence_percent']),
            );
          }
          if (item is List && item.length >= 2) {
            final probability = _score01(item[1]);
            return EmotionScore(
              emotion: _titleCase(item[0].toString()),
              confidence: probability,
              confidencePercent: probability * 100,
            );
          }
          return null;
        })
        .whereType<EmotionScore>()
        .toList();
  }

  ValenceScore _valenceFromJson(Object? value) {
    final map = value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
    final positive = _score01(map['positive']);
    final negative = _score01(map['negative']);
    final neutral = _score01(map['neutral']);
    return ValenceScore(
      positive: positive,
      negative: negative,
      neutral: neutral,
      positivePercent: _asDouble(map['positive_percent']) == 0
          ? positive * 100
          : _asDouble(map['positive_percent']),
      negativePercent: _asDouble(map['negative_percent']) == 0
          ? negative * 100
          : _asDouble(map['negative_percent']),
      neutralPercent: _asDouble(map['neutral_percent']) == 0
          ? neutral * 100
          : _asDouble(map['neutral_percent']),
    );
  }

  double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _score01(Object? value) {
    final score = _asDouble(value);
    if (score > 1 && score <= 100) {
      return score / 100;
    }
    return score.clamp(0, 1).toDouble();
  }

  String _confidenceLabel(double percent) {
    if (percent >= 90) return 'Very high';
    if (percent >= 75) return 'High';
    if (percent >= 55) return 'Moderate';
    if (percent >= 35) return 'Low';
    return 'Very low';
  }

  _EmotionDisplay _displayEmotion(String emotion) {
    final normalized = emotion.toLowerCase();

    if (_positiveEmotions.contains(normalized)) {
      return _EmotionDisplay(
        label: _titleCase(emotion),
        icon: normalized == 'relief'
            ? Icons.spa_outlined
            : Icons.sentiment_very_satisfied,
        color: MoodPalette.happy,
      );
    }

    if (_negativeEmotions.contains(normalized)) {
      final isAnger = normalized == 'anger' || normalized == 'annoyance';
      return _EmotionDisplay(
        label: _titleCase(emotion),
        icon: isAnger
            ? Icons.sentiment_very_dissatisfied
            : Icons.sentiment_dissatisfied,
        color: isAnger ? MoodPalette.angry : MoodPalette.sad,
      );
    }

    if (normalized == 'anxiety' || normalized == 'fear') {
      return _EmotionDisplay(
        label: _titleCase(emotion),
        icon: Icons.psychology_outlined,
        color: MoodPalette.stress,
      );
    }

    return _EmotionDisplay(
      label: _titleCase(emotion),
      icon: Icons.sentiment_neutral,
      color: MoodPalette.neutral,
    );
  }

  String _mirrorStatement(String emotion) {
    final normalized = emotion.toLowerCase();
    if (_positiveEmotions.contains(normalized)) {
      return 'You seem to be experiencing a positive emotional state with a clear signal from the model.';
    }
    if (_negativeEmotions.contains(normalized)) {
      return 'You seem to be carrying a difficult emotional tone that may need care and attention.';
    }
    if (normalized == 'anxiety' || normalized == 'fear') {
      return 'You seem to be noticing tension or uncertainty, with the model reading that pressure clearly.';
    }
    return 'You seem to be reflecting with a more mixed or neutral emotional tone.';
  }

  String _titleCase(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
}

class _EmotionDisplay {
  const _EmotionDisplay({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

const _positiveEmotions = {
  'admiration',
  'anticipation',
  'awe',
  'contentment',
  'empathy',
  'excitement',
  'hope',
  'joy',
  'love',
  'pride',
  'relief',
  'trust',
};

const _negativeEmotions = {
  'anger',
  'anxiety',
  'disgust',
  'fear',
  'frustration',
  'grief',
  'guilt',
  'jealousy',
  'loneliness',
  'regret',
  'sadness',
  'shame',
};
