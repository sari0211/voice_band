class AppConstants {
  // Azure Speech Services
  static const String azureSubscriptionKey =
      String.fromEnvironment('AZURE_SPEECH_KEY');
  static const String azureRegion =
      String.fromEnvironment('AZURE_SPEECH_REGION', defaultValue: 'westeurope');

  // Azure TTS
  static const String ttsVoiceName = 'en-US-JennyNeural';
  static const String ttsOutputFormat = 'audio-16khz-32kbitrate-mono-mp3';

  // Gemini coach (optional - leave key empty to disable AI summary)
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String geminiModel = 'gemini-2.5-flash-lite';

  // Recording
  static const int maxRecordingDurationSeconds = 120; // 2 minutes
  static const int minRecordingDurationSeconds = 60; // 1 minute
  static const int sampleRate = 16000;
  static const int audioChunkMaxSeconds = 55;

  // Scoring thresholds (overall score → IELTS band)
  static const Map<int, double> bandThresholds = {
    90: 9.0,
    80: 8.0,
    70: 7.0,
    60: 6.0,
    50: 5.0,
    40: 4.0,
    30: 3.0,
    20: 2.0,
    0: 1.0,
  };

  // Score weights
  static const double pronunciationWeight = 0.3;
  static const double fluencyWeight = 0.3;
  static const double prosodyWeight = 0.2;
  static const double completenessWeight = 0.2;
}
