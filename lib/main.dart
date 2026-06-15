import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/audio_recorder_service.dart';
import 'services/azure_speech_service.dart';
import 'services/azure_tts_service.dart';
import 'services/gemini_coach_service.dart';
import 'services/storage_service.dart';
import 'providers/recordings_provider.dart';
import 'providers/recording_session_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();

  final geminiCoachService = GeminiCoachService();
  final azureSpeechService =
      AzureSpeechService(coachService: geminiCoachService);
  final azureTtsService = AzureTtsService();
  final audioRecorderService = AudioRecorderService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => RecordingsProvider(storageService, azureSpeechService),
        ),
        ChangeNotifierProvider(
          create: (_) => RecordingSessionProvider(audioRecorderService),
        ),
        Provider<AzureTtsService>.value(value: azureTtsService),
        Provider<AzureSpeechService>.value(value: azureSpeechService),
        Provider<AudioRecorderService>.value(value: audioRecorderService),
      ],
      child: const VoiceBandApp(),
    ),
  );
}

class VoiceBandApp extends StatelessWidget {
  const VoiceBandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Band',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
