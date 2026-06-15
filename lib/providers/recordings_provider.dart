import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/recording.dart';
import '../services/azure_speech_service.dart';
import '../services/storage_service.dart';

class RecordingsProvider extends ChangeNotifier {
  final StorageService _storageService;
  final AzureSpeechService _azureSpeechService;

  List<Recording> _recordings = [];
  bool _isLoading = false;

  RecordingsProvider(this._storageService, this._azureSpeechService);

  List<Recording> get recordings => _recordings;
  bool get isLoading => _isLoading;

  Future<void> loadRecordings() async {
    _isLoading = true;
    notifyListeners();

    _recordings = _storageService.getAllRecordings();

    _isLoading = false;
    notifyListeners();
  }

  Future<Recording> createRecording({
    required String audioFilePath,
    required int durationSeconds,
    AssessmentResult? preComputedResult,
  }) async {
    final recording = Recording(
      id: const Uuid().v4(),
      createdAt: DateTime.now(),
      durationSeconds: durationSeconds,
      audioFilePath: audioFilePath,
      isProcessed: preComputedResult != null,
      result: preComputedResult,
    );

    await _storageService.addRecording(recording);
    _recordings = _storageService.getAllRecordings();
    notifyListeners();

    if (preComputedResult == null) {
      // Start assessment in background
      _assessRecording(recording);
    }

    return recording;
  }

  Future<void> _assessRecording(Recording recording) async {
    try {
      final result = await _azureSpeechService
          .assessPronunciation(recording.audioFilePath);

      recording.result = result;
      recording.isProcessed = true;
      recording.errorMessage = null;
    } catch (e) {
      recording.isProcessed = true;
      recording.errorMessage = e.toString();
    }

    await _storageService.updateRecording(recording);
    _recordings = _storageService.getAllRecordings();
    notifyListeners();
  }

  Future<void> retryAssessment(String recordingId) async {
    final recording = _storageService.getRecording(recordingId);
    if (recording == null) return;

    recording.isProcessed = false;
    recording.errorMessage = null;
    recording.result = null;
    await _storageService.updateRecording(recording);
    _recordings = _storageService.getAllRecordings();
    notifyListeners();

    _assessRecording(recording);
  }

  Future<void> deleteRecording(String id) async {
    await _storageService.deleteRecording(id);
    _recordings = _storageService.getAllRecordings();
    notifyListeners();
  }
}
