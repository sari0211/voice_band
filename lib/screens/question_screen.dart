import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/question.dart';
import '../providers/question_session_provider.dart';
import '../providers/recordings_provider.dart';
import '../services/azure_tts_service.dart';
import '../services/audio_recorder_service.dart';
import '../services/azure_speech_service.dart';
import '../utils/ielts_band_mapper.dart';
import '../models/recording.dart';
import '../widgets/coach_summary_card.dart';
import '../widgets/score_card.dart';
import '../widgets/word_highlight.dart';

class QuestionScreen extends StatefulWidget {
  final Question question;

  const QuestionScreen({super.key, required this.question});

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  late final QuestionSessionProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = QuestionSessionProvider(
      ttsService: context.read<AzureTtsService>(),
      recorderService: context.read<AudioRecorderService>(),
      speechService: context.read<AzureSpeechService>(),
      question: widget.question,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.startTts();
    });
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.question.category),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Consumer<QuestionSessionProvider>(
          builder: (context, provider, _) {
            final tooShort = provider.tooShortMessage;
            if (tooShort != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final messenger = ScaffoldMessenger.of(context);
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(tooShort),
                    backgroundColor:
                        Theme.of(context).colorScheme.error,
                    duration: const Duration(seconds: 4),
                  ),
                );
                provider.clearTooShortMessage();
              });
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Question text - always visible
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.question_answer,
                            size: 32,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.question.text,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // State-dependent content
                  _buildStateContent(context, provider),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStateContent(
    BuildContext context,
    QuestionSessionProvider provider,
  ) {
    switch (provider.state) {
      case QuestionSessionState.idle:
        return const Center(child: CircularProgressIndicator());

      case QuestionSessionState.playingQuestion:
        return _buildPlayingState(context);

      case QuestionSessionState.waitingForRecord:
        return _buildWaitingState(context, provider);

      case QuestionSessionState.recording:
        return _buildRecordingState(context, provider);

      case QuestionSessionState.processing:
        return _buildProcessingState(context);

      case QuestionSessionState.completed:
        return _buildCompletedState(context, provider);

      case QuestionSessionState.error:
        return _buildErrorState(context, provider);
    }
  }

  Widget _buildPlayingState(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.volume_up,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Listen to the question...',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        const LinearProgressIndicator(),
      ],
    );
  }

  Widget _buildWaitingState(
    BuildContext context,
    QuestionSessionProvider provider,
  ) {
    return Column(
      children: [
        Text(
          'Now record your answer',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: () => provider.startRecording(),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.mic, color: Colors.white, size: 48),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Tap to start recording',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingState(
    BuildContext context,
    QuestionSessionProvider provider,
  ) {
    return Column(
      children: [
        Text(
          provider.timerText,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: provider.progress),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: () => provider.stopRecording(),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.stop, color: Colors.white, size: 48),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Tap to stop recording',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingState(BuildContext context) {
    return const Center(
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Analyzing your speech...'),
        ],
      ),
    );
  }

  Widget _buildCompletedState(
    BuildContext context,
    QuestionSessionProvider provider,
  ) {
    final result = provider.result!;
    final band = IeltsBandMapper.mapScoreToBand(result.overallScore);
    final bandLabel = IeltsBandMapper.bandLabel(band);

    // Save to recordings
    _saveRecording(provider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Band score
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'IELTS Band Score',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  band.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  bandLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Score breakdown
        Row(
          children: [
            Expanded(
              child: ScoreCard(
                label: 'Pronunciation',
                score: result.pronunciationScore,
                icon: Icons.record_voice_over,
              ),
            ),
            Expanded(
              child: ScoreCard(
                label: 'Fluency',
                score: result.fluencyScore,
                icon: Icons.speed,
              ),
            ),
            Expanded(
              child: ScoreCard(
                label: 'Completeness',
                score: result.completenessScore,
                icon: Icons.check_circle_outline,
              ),
            ),
            Expanded(
              child: ScoreCard(
                label: 'Prosody',
                score: result.prosodyScore,
                icon: Icons.music_note,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Additional metrics row
        Row(
          children: [
            Expanded(
              child: ScoreCard(
                label: 'Speech Rate',
                score: result.speechRate,
                icon: Icons.timer,
                displayAsWpm: true,
              ),
            ),
            Expanded(
              child: ScoreCard(
                label: 'Pauses',
                score: result.pauseCount.toDouble(),
                icon: Icons.pause_circle_outline,
                displayAsCount: true,
              ),
            ),
            Expanded(
              child: ScoreCard(
                label: 'Vocabulary',
                score: result.vocabularyScore,
                icon: Icons.menu_book,
              ),
            ),
            Expanded(
              child: ScoreCard(
                label: 'Coherence',
                score: result.coherenceScore,
                icon: Icons.link,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Transcript
        Text('Transcript', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: WordHighlight(words: result.words),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          children: [
            _legendItem('Good (80+)', Colors.green.shade700),
            _legendItem('Fair (50-79)', Colors.orange.shade700),
            _legendItem('Needs work (<50)', Colors.red.shade700),
          ],
        ),
        const SizedBox(height: 24),

        // AI Coach summary
        if (result.coachSummary != null) ...[
          CoachSummaryCard(summary: result.coachSummary!),
          const SizedBox(height: 24),
        ],

        // Feedback section
        if (result.feedback.isNotEmpty) ...[
          Text('Feedback',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...result.feedback
              .map((item) => _buildFeedbackCard(context, item)),
          const SizedBox(height: 24),
        ],

        // Try Again button
        ElevatedButton.icon(
          onPressed: () => provider.retry(),
          icon: const Icon(Icons.refresh),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    QuestionSessionProvider provider,
  ) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            provider.errorMessage ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => provider.retry(),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(BuildContext context, FeedbackItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _feedbackIcon(item.type),
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  if (item.suggestion != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.suggestion!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _feedbackIcon(String type) {
    switch (type) {
      case 'pronunciation':
        return Icons.record_voice_over;
      case 'fluency':
        return Icons.speed;
      case 'speech_rate':
        return Icons.timer;
      case 'pauses':
        return Icons.pause_circle_outline;
      case 'vocabulary':
        return Icons.menu_book;
      case 'coherence':
        return Icons.link;
      default:
        return Icons.lightbulb_outline;
    }
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: color, width: 1),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  bool _saved = false;

  void _saveRecording(QuestionSessionProvider provider) {
    if (_saved) return;
    _saved = true;

    final path = provider.currentFilePath;
    final duration = provider.elapsedSeconds;
    if (path != null && duration > 0) {
      context.read<RecordingsProvider>().createRecording(
        audioFilePath: path,
        durationSeconds: duration,
        preComputedResult: provider.result,
      );
    }
  }
}
