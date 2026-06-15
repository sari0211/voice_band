import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/recording.dart';
import '../utils/constants.dart';

class GeminiCoachService {
  final String _apiKey;
  final String _model;

  GeminiCoachService({String? apiKey, String? model})
      : _apiKey = apiKey ?? AppConstants.geminiApiKey,
        _model = model ?? AppConstants.geminiModel;

  bool get isConfigured =>
      _apiKey.isNotEmpty && _apiKey != 'YOUR_GEMINI_KEY';

  /// Returns null if the service isn't configured or the call fails.
  /// Failures are intentionally non-fatal — coach summary is enhancement,
  /// not a hard requirement of the assessment pipeline.
  Future<CoachSummary?> generateSummary({
    required AssessmentResult result,
    String? questionText,
  }) async {
    if (!isConfigured) return null;
    if (result.transcript.trim().isEmpty) return null;

    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
      );

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': _buildPrompt(result, questionText)}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.5,
            'responseMimeType': 'application/json',
            'responseSchema': {
              'type': 'object',
              'properties': {
                'overall': {'type': 'string'},
                'strengths': {
                  'type': 'array',
                  'items': {'type': 'string'},
                },
                'weaknesses': {
                  'type': 'array',
                  'items': {'type': 'string'},
                },
                'tips': {
                  'type': 'array',
                  'items': {'type': 'string'},
                },
              },
              'required': ['overall', 'strengths', 'weaknesses', 'tips'],
            },
          }
        }),
      );

      if (response.statusCode != 200) {
        debugPrint(
            'Gemini coach failed (${response.statusCode}): ${response.body}');
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;

      final content = (candidates[0] as Map<String, dynamic>)['content']
          as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) return null;

      final text = (parts[0] as Map<String, dynamic>)['text'] as String?;
      if (text == null || text.trim().isEmpty) return null;

      final parsed = jsonDecode(text) as Map<String, dynamic>;
      return CoachSummary.fromJson(parsed);
    } catch (e) {
      debugPrint('Gemini coach error: $e');
      return null;
    }
  }

  String _buildPrompt(AssessmentResult result, String? questionText) {
    final mispronounced = result.words
        .where((w) =>
            w.errorType == 'Mispronunciation' || w.accuracyScore < 60)
        .take(10)
        .map((w) => w.word)
        .join(', ');

    final buffer = StringBuffer()
      ..writeln(
          'You are an experienced IELTS speaking coach. Review the candidate response below and produce concise, encouraging, actionable feedback at the candidate\'s level.')
      ..writeln();

    if (questionText != null && questionText.isNotEmpty) {
      buffer.writeln('Question: "$questionText"');
      buffer.writeln();
    }

    buffer
      ..writeln('Candidate transcript:')
      ..writeln('"${result.transcript}"')
      ..writeln()
      ..writeln('Scores (0-100):')
      ..writeln('- Pronunciation: ${result.pronunciationScore.toStringAsFixed(1)}')
      ..writeln('- Fluency: ${result.fluencyScore.toStringAsFixed(1)}')
      ..writeln('- Completeness: ${result.completenessScore.toStringAsFixed(1)}')
      ..writeln('- Prosody: ${result.prosodyScore.toStringAsFixed(1)}')
      ..writeln('- Vocabulary: ${result.vocabularyScore.toStringAsFixed(1)}')
      ..writeln('- Coherence: ${result.coherenceScore.toStringAsFixed(1)}')
      ..writeln('- Speech rate: ${result.speechRate.toStringAsFixed(0)} WPM')
      ..writeln('- Significant pauses: ${result.pauseCount}');

    if (mispronounced.isNotEmpty) {
      buffer.writeln('- Words with low pronunciation accuracy: $mispronounced');
    }

    buffer
      ..writeln()
      ..writeln('Return JSON with these fields:')
      ..writeln('- overall: one or two sentence verdict, warm but honest.')
      ..writeln(
          '- strengths: 2-4 short, specific things they did well. Reference particular words, phrases, or scores.')
      ..writeln(
          '- weaknesses: 2-4 short, concrete issues to address. No generic advice.')
      ..writeln(
          '- tips: 2-4 actionable practice suggestions tailored to the weaknesses above.')
      ..writeln()
      ..writeln(
          'Be specific and reference the transcript when useful. Avoid generic praise. Each bullet should be one sentence.');

    return buffer.toString();
  }
}
