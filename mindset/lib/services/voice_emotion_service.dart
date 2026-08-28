import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/models.dart';
import '../theme/mindset_theme.dart';
import 'emotion_analyzer.dart';

/// Records a short journal clip and posts it to the multimodal API.
class VoiceEmotionService {
  VoiceEmotionService({
    required this.apiBaseUrl,
    http.Client? client,
    AudioRecorder? recorder,
  }) : _client = client ?? http.Client(),
       _recorder = recorder ?? AudioRecorder();

  final String apiBaseUrl;
  final http.Client _client;
  final AudioRecorder _recorder;

  bool _isRecording = false;
  String? _activePath;

  bool get isRecording => _isRecording;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> startRecording() async {
    if (_isRecording) {
      return;
    }
    final allowed = await _recorder.hasPermission();
    if (!allowed) {
      throw const EmotionAnalyzerException(
        'Microphone permission is required for voice reflections. '
        'Allow mic access for MindSet, and on the emulator enable: '
        'Extended controls → Microphone → Virtual mic uses host audio input.',
      );
    }

    final dir = await getTemporaryDirectory();
    // Prefer WAV so the local Python stack (soundfile / Whisper) can decode
    // without needing ffmpeg for AAC/m4a.
    final path =
        '${dir.path}/mindset_voice_${DateTime.now().microsecondsSinceEpoch}.wav';
    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
    } catch (_) {
      // Fallback if WAV encoder is unavailable on this platform build.
      final fallback =
          '${dir.path}/mindset_voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: fallback,
      );
      _activePath = fallback;
      _isRecording = true;
      return;
    }
    _activePath = path;
    _isRecording = true;
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) {
      return _activePath;
    }
    final path = await _recorder.stop();
    _isRecording = false;
    _activePath = path ?? _activePath;
    final saved = _activePath;
    if (saved != null) {
      final file = File(saved);
      if (await file.exists()) {
        final bytes = await file.length();
        if (bytes < 2000) {
          throw const EmotionAnalyzerException(
            'Recording is almost empty. Speak for 2–5 seconds after Start, '
            'and enable the emulator host microphone '
            '(… → Microphone → use host audio input).',
          );
        }
      }
    }
    return _activePath;
  }

  Future<void> cancelRecording() async {
    if (_isRecording) {
      await _recorder.cancel();
    }
    _isRecording = false;
    final path = _activePath;
    _activePath = null;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// Calls POST /predict_multimodal and maps the result into [EmotionResult]
  /// for the existing journal UI. Returns transcript + fusion metadata too.
  Future<VoiceAnalysisOutcome> analyzeRecording(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const EmotionAnalyzerException('Recording file was not found.');
    }
    final size = await file.length();
    if (size < 2000) {
      throw EmotionAnalyzerException(
        'Recording too small ($size bytes). Speak longer, or enable the '
        'emulator host mic (Extended controls → Microphone).',
      );
    }

    final base = apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/predict_multimodal');
    final filename = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'voice.wav';

    try {
      final request = http.MultipartRequest('POST', uri)
        ..fields['language'] = 'en'
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            filePath,
            filename: filename,
          ),
        );

      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 120));
      final body = await streamed.stream.bytesToString();
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object.');
      }
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        final detail = decoded['detail']?.toString();
        throw EmotionAnalyzerException(
          detail == null || detail.isEmpty
              ? 'Multimodal API returned status ${streamed.statusCode}.'
              : detail,
        );
      }
      return VoiceAnalysisOutcome.fromJson(decoded);
    } on TimeoutException {
      throw const EmotionAnalyzerException(
        'Voice analysis took too long. Check the local AI server.',
      );
    } on http.ClientException catch (error) {
      throw EmotionAnalyzerException(
        'Could not reach multimodal API at $uri. ${error.message}',
      );
    } on FormatException {
      throw const EmotionAnalyzerException(
        'The multimodal API returned a response the app could not read.',
      );
    }
  }

  Future<void> dispose() async {
    await cancelRecording();
    _recorder.dispose();
  }
}

class VoiceAnalysisOutcome {
  const VoiceAnalysisOutcome({
    required this.transcript,
    required this.result,
    this.textResult,
    this.audioResult,
    this.provisionalEmotion,
    this.provisionalConfidence,
    this.provisionalReason,
    this.strategy,
    this.pipeline,
    this.sttOk = true,
    this.sttMs,
    this.audioMs,
    this.textMs,
    this.derivedState,
    this.fusionSignals,
  });

  /// Spoken words from STT.
  final String transcript;

  /// Combined / best result used for save + main card.
  final EmotionResult result;

  /// Emotion from transcript words (text BERT), if available.
  final EmotionResult? textResult;

  /// Emotion from voice tone (audio SER), if available.
  final EmotionResult? audioResult;

  final String? provisionalEmotion;
  final double? provisionalConfidence;
  final String? provisionalReason;
  final String? strategy;
  final Map<String, dynamic>? pipeline;
  final bool sttOk;
  final int? sttMs;
  final int? audioMs;
  final int? textMs;
  final Map<String, dynamic>? derivedState;
  final Map<String, dynamic>? fusionSignals;

  bool get hasTranscript => transcript.trim().isNotEmpty;
  bool get hasTextSignal => textResult != null;
  bool get hasAudioSignal => audioResult != null;

  factory VoiceAnalysisOutcome.fromJson(Map<String, dynamic> json) {
    final transcriptMap = Map<String, dynamic>.from(
      json['transcript'] as Map? ?? const {},
    );
    final transcript = transcriptMap['text']?.toString() ?? '';
    final sttOk = transcriptMap['ok'] != false;

    final textPred = json['text_prediction'];
    final audioPred = json['audio_prediction'];
    final provisional = Map<String, dynamic>.from(
      json['provisional_final'] as Map? ?? const {},
    );
    final pipeline = json['pipeline'] is Map
        ? Map<String, dynamic>.from(json['pipeline'] as Map)
        : null;
    final derivedState = provisional['derived_state'] is Map
        ? Map<String, dynamic>.from(provisional['derived_state'] as Map)
        : null;
    final fusionSignals = provisional['signals'] is Map
        ? Map<String, dynamic>.from(provisional['signals'] as Map)
        : null;

    EmotionResult? textResult;
    if (textPred is Map) {
      textResult = _mapApiEmotion(Map<String, dynamic>.from(textPred));
    }

    EmotionResult? audioResult;
    if (audioPred is Map) {
      audioResult = _mapApiEmotion(Map<String, dynamic>.from(audioPred));
    }

    final fusedLabel = provisional['emotion']?.toString();
    final fusedConf = provisional['confidence'];
    double? fusedConfD;
    if (fusedConf is num) {
      fusedConfD = fusedConf.toDouble();
      if (fusedConfD > 1) fusedConfD = fusedConfD / 100;
    }

    // Build combined result: start from the richer source that matches fusion.
    EmotionResult combined;
    final fusedNorm = (fusedLabel ?? '').toLowerCase();
    if (textResult != null &&
        textResult.rawEmotion.toLowerCase() == fusedNorm) {
      combined = textResult;
    } else if (audioResult != null &&
        (audioResult.rawEmotion.toLowerCase() == fusedNorm ||
            audioResult.label.toLowerCase() == fusedNorm)) {
      combined = audioResult;
    } else if (textResult != null && fusedLabel == null) {
      combined = textResult;
    } else if (audioResult != null && fusedLabel == null) {
      combined = audioResult;
    } else {
      final source = <String, dynamic>{
        'emotion':
            fusedLabel ??
            textResult?.rawEmotion ??
            audioResult?.rawEmotion ??
            'unknown',
        'confidence':
            fusedConfD ??
            (textResult?.confidencePercent ??
                    audioResult?.confidencePercent ??
                    0) /
                100,
        'summary':
            provisional['reason']?.toString() ??
            textResult?.summary ??
            audioResult?.summary ??
            '',
        'top_emotions': textResult != null
            ? textPred is Map
                  ? textPred['top_emotions']
                  : null
            : audioPred is Map
            ? audioPred['top_emotions']
            : null,
        'valence': textResult != null
            ? textPred is Map
                  ? textPred['valence']
                  : null
            : audioPred is Map
            ? audioPred['valence']
            : null,
        'certainty_score':
            textResult?.certaintyScore ?? audioResult?.certaintyScore,
        'entropy': textResult?.entropy ?? audioResult?.entropy,
        'confidence_label':
            textResult?.confidenceLabel ?? audioResult?.confidenceLabel,
      };
      combined = _mapApiEmotion(source);
    }

    // If fusion label differs from chosen base, retitle combined for display.
    if (fusedLabel != null &&
        fusedLabel.isNotEmpty &&
        combined.rawEmotion.toLowerCase() != fusedLabel.toLowerCase() &&
        combined.label.toLowerCase() != fusedLabel.toLowerCase()) {
      final confPct = (fusedConfD ?? combined.confidencePercent / 100) * 100;
      final display = _display(fusedLabel);
      combined = EmotionResult(
        label: display.$1,
        rawEmotion: fusedLabel,
        icon: display.$2,
        color: display.$3,
        confidence: confPct.round(),
        confidencePercent: confPct,
        confidenceLabel: _confLabel(confPct),
        certaintyScore: combined.certaintyScore,
        entropy: combined.entropy,
        mirrorStatement: _mirror(fusedLabel),
        summary: provisional['reason']?.toString().isNotEmpty == true
            ? provisional['reason'].toString()
            : combined.summary,
        tags: combined.tags,
        topEmotions: combined.topEmotions,
        valence: combined.valence,
      );
    }

    return VoiceAnalysisOutcome(
      transcript: transcript,
      result: combined,
      textResult: textResult,
      audioResult: audioResult,
      provisionalEmotion: fusedLabel,
      provisionalConfidence: fusedConfD,
      provisionalReason: provisional['reason']?.toString(),
      strategy: provisional['strategy']?.toString(),
      pipeline: pipeline,
      sttOk: sttOk,
      sttMs: pipeline?['stt_ms'] is num
          ? (pipeline!['stt_ms'] as num).toInt()
          : null,
      audioMs: pipeline?['audio_ms'] is num
          ? (pipeline!['audio_ms'] as num).toInt()
          : null,
      textMs: pipeline?['text_ms'] is num
          ? (pipeline!['text_ms'] as num).toInt()
          : null,
      derivedState: derivedState,
      fusionSignals: fusionSignals,
    );
  }
}

// Local mapping helpers (mirrors EmotionAnalyzer response shape).
EmotionResult _mapApiEmotion(Map<String, dynamic> json) {
  final rawEmotion =
      json['primary_emotion']?.toString() ??
      json['emotion']?.toString() ??
      'neutral';
  final confidenceRaw =
      json['primary_prob'] ??
      json['confidence'] ??
      json['confidence_percent'] ??
      0;
  double conf = confidenceRaw is num
      ? confidenceRaw.toDouble()
      : double.tryParse(confidenceRaw.toString()) ?? 0;
  if (conf > 1 && conf <= 100) {
    conf = conf / 100;
  }
  conf = conf.clamp(0, 1).toDouble();
  final confidencePercent = conf * 100;

  final topRaw = json['top_emotions'];
  final topEmotions = <EmotionScore>[];
  if (topRaw is List) {
    for (final item in topRaw) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        var p =
            map['prob'] ??
            map['probability'] ??
            map['score'] ??
            map['confidence'] ??
            0;
        double prob = p is num ? p.toDouble() : double.tryParse('$p') ?? 0;
        if (prob > 1 && prob <= 100) prob = prob / 100;
        final name =
            map['emotion']?.toString() ?? map['label']?.toString() ?? 'unknown';
        topEmotions.add(
          EmotionScore(
            emotion: _titleCase(name),
            confidence: prob,
            confidencePercent: prob * 100,
          ),
        );
      }
    }
  }

  final valenceMap = json['valence'] is Map
      ? Map<String, dynamic>.from(json['valence'] as Map)
      : <String, dynamic>{};
  double vp(String base) {
    final pct = valenceMap['${base}Percent'] ?? valenceMap['${base}_percent'];
    if (pct != null) {
      return pct is num ? pct.toDouble() : double.tryParse('$pct') ?? 0;
    }
    final raw = valenceMap[base] ?? 0;
    final unit = raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0;
    return unit <= 1 ? unit * 100 : unit;
  }

  final display = _display(rawEmotion);
  final certainty = json['certainty_score'] ?? json['certaintyScore'] ?? 0;
  final entropy = json['entropy'] ?? 0;

  return EmotionResult(
    label: display.$1,
    rawEmotion: rawEmotion,
    icon: display.$2,
    color: display.$3,
    confidence: confidencePercent.round(),
    confidencePercent: confidencePercent,
    confidenceLabel:
        json['confidence_label']?.toString() ??
        json['confidenceLabel']?.toString() ??
        _confLabel(confidencePercent),
    certaintyScore: certainty is num
        ? certainty.toDouble()
        : double.tryParse('$certainty') ?? 0,
    entropy: entropy is num
        ? entropy.toDouble()
        : double.tryParse('$entropy') ?? 0,
    mirrorStatement: _mirror(rawEmotion),
    summary:
        json['ai_summary']?.toString() ??
        json['summary']?.toString() ??
        'No summary was returned.',
    tags: topEmotions.map((e) => e.emotion).take(3).toList(),
    topEmotions: topEmotions,
    valence: ValenceScore(
      positive: vp('positive') / 100,
      negative: vp('negative') / 100,
      neutral: vp('neutral') / 100,
      positivePercent: vp('positive'),
      negativePercent: vp('negative'),
      neutralPercent: vp('neutral'),
    ),
  );
}

String _titleCase(String value) {
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((p) => p.isNotEmpty)
      .map((p) => p[0].toUpperCase() + p.substring(1))
      .join(' ');
}

String _confLabel(double percent) {
  if (percent >= 90) return 'Very high';
  if (percent >= 75) return 'High';
  if (percent >= 55) return 'Moderate';
  if (percent >= 35) return 'Low';
  return 'Very low';
}

(String, IconData, Color) _display(String emotion) {
  final n = emotion.toLowerCase();
  const positive = {
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
    'happy',
    'calm',
    'gratitude',
  };
  const negative = {
    'anger',
    'angry',
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
    'sad',
    'shame',
  };
  if (positive.contains(n)) {
    return (
      _titleCase(emotion),
      n == 'relief' || n == 'calm'
          ? Icons.spa_outlined
          : Icons.sentiment_very_satisfied,
      MoodPalette.happy,
    );
  }
  if (n == 'anxiety' || n == 'fear' || n == 'stress') {
    return (_titleCase(emotion), Icons.psychology_outlined, MoodPalette.stress);
  }
  if (negative.contains(n)) {
    final anger = n == 'anger' || n == 'angry' || n == 'frustration';
    return (
      _titleCase(emotion),
      anger ? Icons.sentiment_very_dissatisfied : Icons.sentiment_dissatisfied,
      anger ? MoodPalette.angry : MoodPalette.sad,
    );
  }
  return (_titleCase(emotion), Icons.sentiment_neutral, MoodPalette.neutral);
}

String _mirror(String emotion) {
  final n = emotion.toLowerCase();
  if (n == 'anxiety' || n == 'fear') {
    return 'You seem to be noticing tension or uncertainty in this reflection.';
  }
  if ({
    'anger',
    'angry',
    'sad',
    'sadness',
    'disgust',
    'frustration',
  }.contains(n)) {
    return 'You seem to be carrying a difficult emotional tone that may need care.';
  }
  if ({'happy', 'joy', 'calm', 'relief', 'gratitude', 'love'}.contains(n)) {
    return 'You seem to be expressing a warmer, more settled emotional tone.';
  }
  return 'You seem to be reflecting with a mixed or neutral emotional tone.';
}
