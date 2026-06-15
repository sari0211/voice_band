import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/recording.dart';

class StorageService {
  late final String _dbPath;
  List<Recording> _recordings = [];

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _dbPath = '${dir.path}/voice_band_recordings/recordings.json';
    await _load();
  }

  Future<void> _load() async {
    final file = File(_dbPath);
    if (await file.exists()) {
      final content = await file.readAsString();
      if (content.isNotEmpty) {
        final list = jsonDecode(content) as List;
        _recordings = list
            .map((e) => Recording.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
  }

  Future<void> _save() async {
    final file = File(_dbPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(_recordings.map((r) => r.toJson()).toList()),
    );
  }

  List<Recording> getAllRecordings() {
    return List.unmodifiable(
      _recordings..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
  }

  Recording? getRecording(String id) {
    try {
      return _recordings.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addRecording(Recording recording) async {
    _recordings.add(recording);
    await _save();
  }

  Future<void> updateRecording(Recording recording) async {
    final index = _recordings.indexWhere((r) => r.id == recording.id);
    if (index != -1) {
      _recordings[index] = recording;
      await _save();
    }
  }

  Future<void> deleteRecording(String id) async {
    final recording = getRecording(id);
    if (recording != null) {
      // Delete audio file
      final audioFile = File(recording.audioFilePath);
      if (await audioFile.exists()) {
        await audioFile.delete();
      }
      _recordings.removeWhere((r) => r.id == id);
      await _save();
    }
  }
}
