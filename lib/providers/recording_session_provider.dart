import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/audio_recorder_service.dart';
import '../utils/constants.dart';

class RecordingSessionProvider extends ChangeNotifier {
  final AudioRecorderService _recorderService;

  bool _isRecording = false;
  int _elapsedSeconds = 0;
  String? _currentFilePath;
  Timer? _timer;
  String? _errorMessage;

  RecordingSessionProvider(this._recorderService);

  bool get isRecording => _isRecording;
  int get elapsedSeconds => _elapsedSeconds;
  int get maxSeconds => AppConstants.maxRecordingDurationSeconds;
  String? get currentFilePath => _currentFilePath;
  String? get errorMessage => _errorMessage;

  String get timerText {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '${minutes.toString()}:${seconds.toString().padLeft(2, '0')}';
  }

  String get maxTimerText {
    final minutes = maxSeconds ~/ 60;
    final seconds = maxSeconds % 60;
    return '${minutes.toString()}:${seconds.toString().padLeft(2, '0')}';
  }

  double get progress => _elapsedSeconds / maxSeconds;

  Future<void> startRecording() async {
    _errorMessage = null;

    final hasPermission = await _recorderService.hasPermission();
    if (!hasPermission) {
      _errorMessage = 'Microphone permission denied';
      notifyListeners();
      return;
    }

    try {
      _currentFilePath = await _recorderService.startRecording();
      _isRecording = true;
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
      _errorMessage = 'Failed to start recording: $e';
      notifyListeners();
    }
  }

  Future<String?> stopRecording() async {
    _timer?.cancel();
    _timer = null;

    if (!_isRecording) return null;

    try {
      await _recorderService.stopRecording();
    } catch (e) {
      _errorMessage = 'Failed to stop recording: $e';
    }

    _isRecording = false;
    final path = _currentFilePath;
    notifyListeners();
    return path;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
