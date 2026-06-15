import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/question.dart';
import '../models/recording.dart';
import '../services/azure_tts_service.dart';
import '../services/audio_recorder_service.dart';
import '../services/azure_speech_service.dart';
import '../utils/constants.dart';

enum QuestionSessionState {
  idle,
  playingQuestion,
  waitingForRecord,
  recording,
  processing,
  completed,
  error,
}

class QuestionSessionProvider extends ChangeNotifier {
  final AzureTtsService _ttsService;
  final AudioRecorderService _recorderService;
  final AzureSpeechService _speechService;
  final Question question;

  final AudioPlayer _player = AudioPlayer();

  QuestionSessionState _state = QuestionSessionState.idle;
  AssessmentResult? _result;
  String? _errorMessage;
  String? _tooShortMessage;
  int _elapsedSeconds = 0;
  String? _currentFilePath;
  Timer? _timer;
  StreamSubscription? _playerSubscription;

  QuestionSessionProvider({
    required AzureTtsService ttsService,
    required AudioRecorderService recorderService,
    required AzureSpeechService speechService,
    required this.question,
  })  : _ttsService = ttsService,
        _recorderService = recorderService,
        _speechService = speechService;

  QuestionSessionState get state => _state;
  AssessmentResult? get result => _result;
  String? get errorMessage => _errorMessage;
  String? get tooShortMessage => _tooShortMessage;
  int get elapsedSeconds => _elapsedSeconds;
  int get maxSeconds => AppConstants.maxRecordingDurationSeconds;
  int get minSeconds => AppConstants.minRecordingDurationSeconds;
  String? get currentFilePath => _currentFilePath;

  void clearTooShortMessage() {
    if (_tooShortMessage == null) return;
    _tooShortMessage = null;
    notifyListeners();
  }

  String get timerText {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '${minutes.toString()}:${seconds.toString().padLeft(2, '0')}';
  }

  double get progress => _elapsedSeconds / maxSeconds;

  Future<void> startTts() async {
    _state = QuestionSessionState.playingQuestion;
    _errorMessage = null;
    notifyListeners();

    try {
      final audioBytes = await _ttsService.synthesize(question.text);

      _playerSubscription?.cancel();
      _playerSubscription = _player.onPlayerComplete.listen((_) {
        _state = QuestionSessionState.waitingForRecord;
        notifyListeners();
      });

      await _player.setSource(BytesSource(audioBytes));
      await _player.resume();
    } catch (e) {
      _state = QuestionSessionState.error;
      _errorMessage = 'Failed to play question: $e';
      notifyListeners();
    }
  }

  Future<void> startRecording() async {
    _errorMessage = null;
    _tooShortMessage = null;

    final hasPermission = await _recorderService.hasPermission();
    if (!hasPermission) {
      _state = QuestionSessionState.error;
      _errorMessage = 'Microphone permission denied';
      notifyListeners();
      return;
    }

    try {
      _currentFilePath = await _recorderService.startRecording();
      _state = QuestionSessionState.recording;
      _elapsedSeconds = 0;
      notifyListeners();

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _elapsedSeconds++;
        notifyListeners();

        if (_elapsedSeconds >= maxSeconds) {
          stopRecording();
        }
      });
    } catch (e) {
      _state = QuestionSessionState.error;
      _errorMessage = 'Failed to start recording: $e';
      notifyListeners();
    }
  }

  Future<void> stopRecording() async {
    _timer?.cancel();
    _timer = null;

    if (_state != QuestionSessionState.recording) return;

    final recordedSeconds = _elapsedSeconds;

    try {
      await _recorderService.stopRecording();
    } catch (e) {
      _state = QuestionSessionState.error;
      _errorMessage = 'Failed to stop recording: $e';
      notifyListeners();
      return;
    }

    if (recordedSeconds < minSeconds) {
      final path = _currentFilePath;
      if (path != null) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (_) {
          // best-effort cleanup; ignore failures
        }
      }
      _currentFilePath = null;
      _elapsedSeconds = 0;
      _tooShortMessage =
          'Recording was only ${recordedSeconds}s. Please speak for at least ${minSeconds}s and try again.';
      _state = QuestionSessionState.waitingForRecord;
      notifyListeners();
      return;
    }

    _state = QuestionSessionState.processing;
    notifyListeners();

    try {
      final assessmentResult = await _speechService.assessPronunciation(
        _currentFilePath!,
        questionText: question.text,
      );
      _result = assessmentResult;
      _state = QuestionSessionState.completed;
    } catch (e) {
      _state = QuestionSessionState.error;
      _errorMessage = 'Assessment failed: $e';
    }
    notifyListeners();
  }

  Future<void> retry() async {
    _result = null;
    _errorMessage = null;
    _tooShortMessage = null;
    _elapsedSeconds = 0;
    _currentFilePath = null;
    _state = QuestionSessionState.idle;
    notifyListeners();
    await startTts();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _playerSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }
}
