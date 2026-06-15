import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import '../providers/recordings_provider.dart';
import '../models/recording.dart';
import '../utils/ielts_band_mapper.dart';
import '../widgets/coach_summary_card.dart';
import '../widgets/score_card.dart';
import '../widgets/word_highlight.dart';

class ResultDetailScreen extends StatefulWidget {
  final String recordingId;

  const ResultDetailScreen({super.key, required this.recordingId});

  @override
  State<ResultDetailScreen> createState() => _ResultDetailScreenState();
}

class _ResultDetailScreenState extends State<ResultDetailScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingsProvider>(
      builder: (context, provider, _) {
        final recording = provider.recordings
            .cast<Recording?>()
            .firstWhere((r) => r!.id == widget.recordingId, orElse: () => null);

        if (recording == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Recording')),
            body: const Center(child: Text('Recording not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Results'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          ),
          body: _buildBody(context, recording, provider),
        );
      },
    );
  }

  Widget _buildBody(
      BuildContext context, Recording recording, RecordingsProvider provider) {
    if (!recording.isProcessed) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Analyzing your speech...'),
          ],
        ),
      );
    }

    if (recording.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Assessment Failed',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                recording.errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () =>
                    provider.retryAssessment(recording.id),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final result = recording.result!;
    final band = IeltsBandMapper.mapScoreToBand(result.overallScore);
    final bandLabel = IeltsBandMapper.bandLabel(band);
    final dateFormat = DateFormat('MMMM d, yyyy  HH:mm');
    final duration = Duration(seconds: recording.durationSeconds);
    final durationText =
        '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Overall band score
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
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer
                              .withValues(alpha: 0.7),
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

          // Score table
          Text(
            'Score Table',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.primaryContainer,
                ),
                columns: const [
                  DataColumn(label: Text('Metric')),
                  DataColumn(label: Text('Result')),
                ],
                rows: [
                  _scoreRow(
                    'Pronunciation',
                    result.pronunciationScore.toStringAsFixed(0),
                  ),
                  _scoreRow('Fluency', result.fluencyScore.toStringAsFixed(0)),
                  _scoreRow(
                    'Completeness',
                    result.completenessScore.toStringAsFixed(0),
                  ),
                  _scoreRow('Prosody', result.prosodyScore.toStringAsFixed(0)),
                  _scoreRow(
                    'Speech Rate',
                    '${result.speechRate.toStringAsFixed(0)} wpm',
                  ),
                  _scoreRow('Pauses', result.pauseCount.toString()),
                  _scoreRow(
                    'Vocabulary',
                    result.vocabularyScore.toStringAsFixed(0),
                  ),
                  _scoreRow(
                    'Coherence',
                    result.coherenceScore.toStringAsFixed(0),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Transcript
          Text(
            'Transcript',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: WordHighlight(words: result.words),
            ),
          ),
          const SizedBox(height: 8),
          // Legend
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

          // Playback
          Card(
            child: ListTile(
              leading: IconButton(
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                iconSize: 32,
                onPressed: () => _togglePlayback(recording.audioFilePath),
              ),
              title: const Text('Audio Playback'),
              subtitle: Text(
                  '${dateFormat.format(recording.createdAt)}  •  $durationText'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  DataRow _scoreRow(String metric, String value) {
    return DataRow(
      cells: [
        DataCell(Text(metric)),
        DataCell(Text(value)),
      ],
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

  Future<void> _togglePlayback(String filePath) async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.stop();
      await _player.setSourceDeviceFile(filePath);
      await _player.resume();
    }
  }
}
