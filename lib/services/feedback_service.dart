import '../models/recording.dart';

class PauseMetrics {
  final int pauseCount;
  final double averagePauseDurationMs;

  PauseMetrics({required this.pauseCount, required this.averagePauseDurationMs});
}

class FeedbackService {
  static const double _pauseThresholdMs = 500;

  static const List<String> _discourseMarkers = [
    'however',
    'therefore',
    'because',
    'although',
    'moreover',
    'furthermore',
    'nevertheless',
    'consequently',
    'additionally',
    'meanwhile',
    'otherwise',
    'instead',
    'similarly',
    'likewise',
    'hence',
    'thus',
    'besides',
    'nonetheless',
    'in addition',
    'on the other hand',
    'for example',
    'for instance',
    'in contrast',
    'as a result',
    'in fact',
    'first',
    'second',
    'third',
    'finally',
    'also',
    'but',
    'so',
    'yet',
    'still',
    'then',
  ];

  double computeSpeechRate(int wordCount, int durationSeconds) {
    if (durationSeconds <= 0) return 0;
    return wordCount / (durationSeconds / 60.0);
  }

  PauseMetrics computePauses(List<WordDetail> words) {
    if (words.length < 2) {
      return PauseMetrics(pauseCount: 0, averagePauseDurationMs: 0);
    }

    final gaps = <double>[];
    for (int i = 1; i < words.length; i++) {
      final prev = words[i - 1];
      final curr = words[i];
      if (prev.offsetMs != null &&
          prev.durationMs != null &&
          curr.offsetMs != null) {
        final prevEnd = prev.offsetMs! + prev.durationMs!;
        final gap = (curr.offsetMs! - prevEnd).toDouble();
        if (gap >= _pauseThresholdMs) {
          gaps.add(gap);
        }
      }
    }

    if (gaps.isEmpty) {
      return PauseMetrics(pauseCount: 0, averagePauseDurationMs: 0);
    }

    final avg = gaps.reduce((a, b) => a + b) / gaps.length;
    return PauseMetrics(pauseCount: gaps.length, averagePauseDurationMs: avg);
  }

  double computeVocabularyScore(String transcript) {
    final words = transcript
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    if (words.isEmpty) return 0;

    final uniqueWords = words.toSet();
    final ttr = uniqueWords.length / words.length;

    // Scale TTR to 0-100. TTR of 1.0 = 100, TTR of 0.3 = ~0.
    // For short responses TTR is naturally high, so also factor in word count.
    double score = (ttr * 100).clamp(0, 100);

    // Bonus for using more unique words (absolute count matters too)
    if (uniqueWords.length >= 30) {
      score = (score + 10).clamp(0, 100);
    } else if (uniqueWords.length >= 20) {
      score = (score + 5).clamp(0, 100);
    }

    // Penalty for very short responses
    if (words.length < 10) {
      score = (score * 0.6).clamp(0, 100);
    } else if (words.length < 20) {
      score = (score * 0.8).clamp(0, 100);
    }

    return score;
  }

  double computeCoherenceScore(String transcript) {
    if (transcript.trim().isEmpty) return 0;

    final lower = transcript.toLowerCase();
    double score = 50; // baseline

    // 1. Discourse markers usage (up to +25)
    int markerCount = 0;
    for (final marker in _discourseMarkers) {
      if (lower.contains(marker)) {
        markerCount++;
      }
    }
    score += (markerCount * 5).clamp(0, 25);

    // 2. Sentence count & variety (up to +15)
    final sentences = transcript
        .split(RegExp(r'[.!?]+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (sentences.length >= 3) {
      score += 10;
      // Sentence length variety
      final lengths = sentences.map((s) => s.trim().split(RegExp(r'\s+')).length).toList();
      if (lengths.isNotEmpty) {
        final avg = lengths.reduce((a, b) => a + b) / lengths.length;
        final variance = lengths.map((l) => (l - avg) * (l - avg)).reduce((a, b) => a + b) / lengths.length;
        if (variance > 4) score += 5; // variety in sentence length
      }
    }

    // 3. Response length adequacy (up to +10)
    final wordCount = transcript.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (wordCount >= 40) {
      score += 10;
    } else if (wordCount >= 20) {
      score += 5;
    }

    return score.clamp(0, 100);
  }

  List<FeedbackItem> generateFeedback(AssessmentResult result) {
    final items = <FeedbackItem>[];

    // Pronunciation feedback - mispronounced words
    final mispronounced = result.words
        .where((w) =>
            w.errorType == 'Mispronunciation' || w.accuracyScore < 60)
        .toList();
    if (mispronounced.isNotEmpty) {
      final wordList =
          mispronounced.take(5).map((w) => '"${w.word}"').join(', ');
      items.add(FeedbackItem(
        type: 'pronunciation',
        message:
            'Some words need pronunciation work: $wordList',
        suggestion:
            'Practice these words individually. Try breaking them into syllables and speaking slowly at first.',
      ));
    }

    if (result.pronunciationScore < 50) {
      items.add(FeedbackItem(
        type: 'pronunciation',
        message: 'Your overall pronunciation score is low (${result.pronunciationScore.toStringAsFixed(0)}).',
        suggestion:
            'Focus on vowel and consonant sounds. Listen to native speakers and try to mimic their pronunciation.',
      ));
    }

    // Fluency feedback
    if (result.fluencyScore < 50) {
      items.add(FeedbackItem(
        type: 'fluency',
        message: 'Your speech fluency needs improvement.',
        suggestion:
            'Try to speak more smoothly without long pauses between words. Practice reading aloud daily.',
      ));
    } else if (result.fluencyScore < 70) {
      items.add(FeedbackItem(
        type: 'fluency',
        message: 'Your fluency is fair but could be smoother.',
        suggestion:
            'Reduce hesitations by preparing key points before speaking. Use linking words to connect ideas.',
      ));
    }

    // Speech rate feedback
    if (result.speechRate > 0) {
      if (result.speechRate < 100) {
        items.add(FeedbackItem(
          type: 'speech_rate',
          message:
              'Your speech rate is slow (${result.speechRate.toStringAsFixed(0)} WPM).',
          suggestion:
              'Aim for 120-150 words per minute. Practice speaking a bit faster while maintaining clarity.',
        ));
      } else if (result.speechRate > 180) {
        items.add(FeedbackItem(
          type: 'speech_rate',
          message:
              'Your speech rate is quite fast (${result.speechRate.toStringAsFixed(0)} WPM).',
          suggestion:
              'Slow down slightly to improve clarity. Aim for 120-150 words per minute for clear communication.',
        ));
      }
    }

    // Pause feedback
    if (result.pauseCount > 5) {
      items.add(FeedbackItem(
        type: 'pauses',
        message:
            'You had ${result.pauseCount} significant pauses in your speech.',
        suggestion:
            'Try to reduce long pauses. If you need to think, use filler phrases like "let me think" instead of silent pauses.',
      ));
    }
    if (result.averagePauseDurationMs > 1500) {
      items.add(FeedbackItem(
        type: 'pauses',
        message:
            'Your average pause duration is long (${(result.averagePauseDurationMs / 1000).toStringAsFixed(1)}s).',
        suggestion:
            'Practice transitioning between ideas more smoothly. Plan your response structure before speaking.',
      ));
    }

    // Vocabulary feedback
    if (result.vocabularyScore < 40) {
      items.add(FeedbackItem(
        type: 'vocabulary',
        message: 'Your vocabulary variety is limited.',
        suggestion:
            'Try to use a wider range of words. Learn synonyms for common words and practice using them in sentences.',
      ));
    } else if (result.vocabularyScore < 60) {
      items.add(FeedbackItem(
        type: 'vocabulary',
        message: 'Your vocabulary is adequate but could be richer.',
        suggestion:
            'Incorporate more advanced vocabulary. Use descriptive adjectives and precise verbs to express your ideas.',
      ));
    }

    // Coherence feedback
    if (result.coherenceScore < 50) {
      items.add(FeedbackItem(
        type: 'coherence',
        message: 'Your response could be more structured and coherent.',
        suggestion:
            'Use discourse markers (however, therefore, for example) to connect your ideas. Structure your answer with an introduction, main points, and conclusion.',
      ));
    } else if (result.coherenceScore < 70) {
      items.add(FeedbackItem(
        type: 'coherence',
        message: 'Your coherence is fair. Try linking ideas more clearly.',
        suggestion:
            'Use transitional phrases between sentences. Make sure each point logically follows the previous one.',
      ));
    }

    // Positive feedback if scores are good
    if (items.isEmpty) {
      items.add(FeedbackItem(
        type: 'general',
        message: 'Great job! Your speech is clear and well-structured.',
        suggestion: 'Keep practicing to maintain and further improve your skills.',
      ));
    }

    return items;
  }
}
