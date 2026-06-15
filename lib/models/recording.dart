import 'dart:convert';

class FeedbackItem {
  final String type; // "pronunciation", "fluency", "vocabulary", "coherence", "speech_rate", "pauses"
  final String message;
  final String? suggestion;

  FeedbackItem({
    required this.type,
    required this.message,
    this.suggestion,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'message': message,
        'suggestion': suggestion,
      };

  factory FeedbackItem.fromJson(Map<String, dynamic> json) => FeedbackItem(
        type: json['type'] as String,
        message: json['message'] as String,
        suggestion: json['suggestion'] as String?,
      );
}

class WordDetail {
  final String word;
  final double accuracyScore;
  final String? errorType; // None, Mispronunciation, Omission, Insertion
  final int? durationMs;
  final int? offsetMs;

  WordDetail({
    required this.word,
    required this.accuracyScore,
    this.errorType,
    this.durationMs,
    this.offsetMs,
  });

  Map<String, dynamic> toJson() => {
        'word': word,
        'accuracyScore': accuracyScore,
        'errorType': errorType,
        'durationMs': durationMs,
        'offsetMs': offsetMs,
      };

  factory WordDetail.fromJson(Map<String, dynamic> json) => WordDetail(
        word: json['word'] as String,
        accuracyScore: (json['accuracyScore'] as num).toDouble(),
        errorType: json['errorType'] as String?,
        durationMs: json['durationMs'] as int?,
        offsetMs: json['offsetMs'] as int?,
      );
}

class CoachSummary {
  final String overall;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> tips;

  CoachSummary({
    required this.overall,
    required this.strengths,
    required this.weaknesses,
    required this.tips,
  });

  Map<String, dynamic> toJson() => {
        'overall': overall,
        'strengths': strengths,
        'weaknesses': weaknesses,
        'tips': tips,
      };

  factory CoachSummary.fromJson(Map<String, dynamic> json) => CoachSummary(
        overall: json['overall'] as String? ?? '',
        strengths:
            (json['strengths'] as List?)?.map((e) => e as String).toList() ??
                const [],
        weaknesses:
            (json['weaknesses'] as List?)?.map((e) => e as String).toList() ??
                const [],
        tips: (json['tips'] as List?)?.map((e) => e as String).toList() ??
            const [],
      );
}

class AssessmentResult {
  final String transcript;
  final double pronunciationScore;
  final double fluencyScore;
  final double completenessScore;
  final double prosodyScore;
  final double overallScore;
  final List<WordDetail> words;
  final double speechRate;
  final int pauseCount;
  final double averagePauseDurationMs;
  final double vocabularyScore;
  final double coherenceScore;
  final List<FeedbackItem> feedback;
  CoachSummary? coachSummary;

  AssessmentResult({
    required this.transcript,
    required this.pronunciationScore,
    required this.fluencyScore,
    required this.completenessScore,
    required this.prosodyScore,
    required this.overallScore,
    required this.words,
    this.speechRate = 0,
    this.pauseCount = 0,
    this.averagePauseDurationMs = 0,
    this.vocabularyScore = 0,
    this.coherenceScore = 0,
    this.feedback = const [],
    this.coachSummary,
  });

  Map<String, dynamic> toJson() => {
        'transcript': transcript,
        'pronunciationScore': pronunciationScore,
        'fluencyScore': fluencyScore,
        'completenessScore': completenessScore,
        'prosodyScore': prosodyScore,
        'overallScore': overallScore,
        'words': words.map((w) => w.toJson()).toList(),
        'speechRate': speechRate,
        'pauseCount': pauseCount,
        'averagePauseDurationMs': averagePauseDurationMs,
        'vocabularyScore': vocabularyScore,
        'coherenceScore': coherenceScore,
        'feedback': feedback.map((f) => f.toJson()).toList(),
        'coachSummary': coachSummary?.toJson(),
      };

  factory AssessmentResult.fromJson(Map<String, dynamic> json) =>
      AssessmentResult(
        transcript: json['transcript'] as String,
        pronunciationScore: (json['pronunciationScore'] as num).toDouble(),
        fluencyScore: (json['fluencyScore'] as num).toDouble(),
        completenessScore: (json['completenessScore'] as num).toDouble(),
        prosodyScore: (json['prosodyScore'] as num).toDouble(),
        overallScore: (json['overallScore'] as num).toDouble(),
        words: (json['words'] as List)
            .map((w) => WordDetail.fromJson(w as Map<String, dynamic>))
            .toList(),
        speechRate: (json['speechRate'] as num?)?.toDouble() ?? 0,
        pauseCount: (json['pauseCount'] as int?) ?? 0,
        averagePauseDurationMs:
            (json['averagePauseDurationMs'] as num?)?.toDouble() ?? 0,
        vocabularyScore: (json['vocabularyScore'] as num?)?.toDouble() ?? 0,
        coherenceScore: (json['coherenceScore'] as num?)?.toDouble() ?? 0,
        feedback: (json['feedback'] as List?)
                ?.map(
                    (f) => FeedbackItem.fromJson(f as Map<String, dynamic>))
                .toList() ??
            [],
        coachSummary: json['coachSummary'] != null
            ? CoachSummary.fromJson(
                json['coachSummary'] as Map<String, dynamic>)
            : null,
      );
}

class Recording {
  final String id;
  final DateTime createdAt;
  final int durationSeconds;
  final String audioFilePath;
  bool isProcessed;
  String? errorMessage;
  AssessmentResult? result;

  Recording({
    required this.id,
    required this.createdAt,
    required this.durationSeconds,
    required this.audioFilePath,
    this.isProcessed = false,
    this.errorMessage,
    this.result,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'durationSeconds': durationSeconds,
        'audioFilePath': audioFilePath,
        'isProcessed': isProcessed,
        'errorMessage': errorMessage,
        'result': result?.toJson(),
      };

  factory Recording.fromJson(Map<String, dynamic> json) => Recording(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        durationSeconds: json['durationSeconds'] as int,
        audioFilePath: json['audioFilePath'] as String,
        isProcessed: json['isProcessed'] as bool,
        errorMessage: json['errorMessage'] as String?,
        result: json['result'] != null
            ? AssessmentResult.fromJson(
                json['result'] as Map<String, dynamic>)
            : null,
      );

  String toJsonString() => jsonEncode(toJson());

  factory Recording.fromJsonString(String jsonString) =>
      Recording.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
}
