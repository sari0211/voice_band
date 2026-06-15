import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/recording.dart';
import '../utils/constants.dart';
import '../utils/ielts_band_mapper.dart';
import 'feedback_service.dart';
import 'gemini_coach_service.dart';

class AzureSpeechService {
  final String _subscriptionKey;
  final String _region;
  final GeminiCoachService? _coachService;

  AzureSpeechService({
    String? subscriptionKey,
    String? region,
    GeminiCoachService? coachService,
  })  : _subscriptionKey = subscriptionKey ?? AppConstants.azureSubscriptionKey,
        _region = region ?? AppConstants.azureRegion,
        _coachService = coachService;

  String get _baseUrl =>
      'https://$_region.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1';

  Future<AssessmentResult> assessPronunciation(
    String audioFilePath, {
    String? questionText,
  }) async {
    _validateConfiguration();

    final audioBytes = await File(audioFilePath).readAsBytes();

    // Step 1: Transcribe
    final transcript = await _transcribe(audioBytes);
    if (transcript.isEmpty) {
      throw Exception('Could not transcribe audio. Please speak more clearly.');
    }

    // Step 2: Pronunciation assessment with the transcript as reference
    final result = await _assess(audioBytes, transcript);

    // Step 3: Best-effort coach summary via Gemini. Failures are swallowed
    // inside the service so the assessment still returns successfully.
    if (_coachService != null) {
      result.coachSummary = await _coachService.generateSummary(
        result: result,
        questionText: questionText,
      );
    }

    return result;
  }

  Future<String> _transcribe(List<int> audioBytes) async {
    final uri = Uri.parse('$_baseUrl?language=en-US&format=detailed');

    final response = await http.post(
      uri,
      headers: {
        'Ocp-Apim-Subscription-Key': _subscriptionKey,
        'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000',
        'Accept': 'application/json',
      },
      body: audioBytes,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Transcription failed (${response.statusCode}). '
        '${_authHintFor(response.statusCode)}${response.body}',
      );
    }

    if (response.body.isEmpty) {
      throw Exception('Transcription returned empty response. '
          'Verify your Azure region and subscription key are correct.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final status = json['RecognitionStatus'] as String?;
    if (status != 'Success') {
      throw Exception('Recognition status: $status');
    }

    // Get best transcript from NBest
    final nBest = json['NBest'] as List?;
    if (nBest == null || nBest.isEmpty) {
      return json['DisplayText'] as String? ?? '';
    }

    return (nBest[0] as Map<String, dynamic>)['Display'] as String? ??
        json['DisplayText'] as String? ??
        '';
  }

  Future<AssessmentResult> _assess(
      List<int> audioBytes, String transcript) async {
    final assessmentConfig = {
      'ReferenceText': transcript,
      'GradingSystem': 'HundredMark',
      'Granularity': 'Word',
      'Dimension': 'Comprehensive',
      'EnableProsodyAssessment': true,
    };

    final encodedConfig = base64Encode(utf8.encode(jsonEncode(assessmentConfig)));

    final uri = Uri.parse('$_baseUrl?language=en-US&format=detailed');

    final response = await http.post(
      uri,
      headers: {
        'Ocp-Apim-Subscription-Key': _subscriptionKey,
        'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000',
        'Accept': 'application/json',
        'Pronunciation-Assessment': encodedConfig,
      },
      body: audioBytes,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Assessment failed (${response.statusCode}). '
        '${_authHintFor(response.statusCode)}${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final nBest = json['NBest'] as List?;

    if (nBest == null || nBest.isEmpty) {
      throw Exception('No assessment results returned');
    }

    final best = nBest[0] as Map<String, dynamic>;

    final pronunciationScore =
        (best['PronScore'] as num?)?.toDouble() ?? 0;
    final fluencyScore =
        (best['FluencyScore'] as num?)?.toDouble() ?? 0;
    final completenessScore =
        (best['CompletenessScore'] as num?)?.toDouble() ?? 0;
    final prosodyScore =
        (best['ProsodyScore'] as num?)?.toDouble() ?? 0;

    // Parse word-level details with timing data
    final wordsJson = best['Words'] as List? ?? [];
    final words = wordsJson.map((w) {
      final wordMap = w as Map<String, dynamic>;
      // Azure returns Offset and Duration in ticks (1 tick = 100ns = 0.0001ms)
      final offsetTicks = (wordMap['Offset'] as num?)?.toInt();
      final durationTicks = (wordMap['Duration'] as num?)?.toInt();
      return WordDetail(
        word: wordMap['Word'] as String? ?? '',
        accuracyScore:
            (wordMap['AccuracyScore'] as num?)?.toDouble() ?? 0,
        errorType: wordMap['ErrorType'] as String?,
        offsetMs: offsetTicks != null ? (offsetTicks / 10000).round() : null,
        durationMs:
            durationTicks != null ? (durationTicks / 10000).round() : null,
      );
    }).toList();

    final overallScore = IeltsBandMapper.calculateOverallScore(
      pronunciation: pronunciationScore,
      fluency: fluencyScore,
      completeness: completenessScore,
      prosody: prosodyScore,
    );

    // Compute additional metrics
    final feedbackService = FeedbackService();
    final durationSeconds = _estimateDurationFromWords(words);
    final speechRate =
        feedbackService.computeSpeechRate(words.length, durationSeconds);
    final pauseMetrics = feedbackService.computePauses(words);
    final vocabularyScore =
        feedbackService.computeVocabularyScore(transcript);
    final coherenceScore =
        feedbackService.computeCoherenceScore(transcript);

    final baseResult = AssessmentResult(
      transcript: transcript,
      pronunciationScore: pronunciationScore,
      fluencyScore: fluencyScore,
      completenessScore: completenessScore,
      prosodyScore: prosodyScore,
      overallScore: overallScore,
      words: words,
      speechRate: speechRate,
      pauseCount: pauseMetrics.pauseCount,
      averagePauseDurationMs: pauseMetrics.averagePauseDurationMs,
      vocabularyScore: vocabularyScore,
      coherenceScore: coherenceScore,
    );

    final feedback = feedbackService.generateFeedback(baseResult);

    return AssessmentResult(
      transcript: transcript,
      pronunciationScore: pronunciationScore,
      fluencyScore: fluencyScore,
      completenessScore: completenessScore,
      prosodyScore: prosodyScore,
      overallScore: overallScore,
      words: words,
      speechRate: speechRate,
      pauseCount: pauseMetrics.pauseCount,
      averagePauseDurationMs: pauseMetrics.averagePauseDurationMs,
      vocabularyScore: vocabularyScore,
      coherenceScore: coherenceScore,
      feedback: feedback,
    );
  }

  int _estimateDurationFromWords(List<WordDetail> words) {
    if (words.isEmpty) return 0;
    // Use timing data from first to last word to estimate total duration
    final firstOffset = words.first.offsetMs;
    final lastOffset = words.last.offsetMs;
    final lastDuration = words.last.durationMs;
    if (firstOffset != null && lastOffset != null && lastDuration != null) {
      return ((lastOffset + lastDuration - firstOffset) / 1000).ceil();
    }
    // Fallback: estimate ~2 words per second
    return (words.length / 2).ceil();
  }

  void _validateConfiguration() {
    if (_subscriptionKey.trim().isEmpty) {
      throw Exception(
        'Azure Speech key is missing. Run the app with '
        '--dart-define=AZURE_SPEECH_KEY=your_key.',
      );
    }

    if (_region.trim().isEmpty) {
      throw Exception(
        'Azure Speech region is missing. Run the app with '
        '--dart-define=AZURE_SPEECH_REGION=your_region.',
      );
    }
  }

  String _authHintFor(int statusCode) {
    if (statusCode != 401 && statusCode != 403) return '';

    return 'Check that AZURE_SPEECH_KEY is current and belongs to the '
        '$_region Speech resource. ';
  }
}
