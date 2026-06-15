import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/recording.dart';
import '../utils/ielts_band_mapper.dart';

class RecordingTile extends StatefulWidget {
  final Recording recording;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const RecordingTile({
    super.key,
    required this.recording,
    required this.onTap,
    this.onDelete,
  });

  @override
  State<RecordingTile> createState() => _RecordingTileState();
}

class _RecordingTileState extends State<RecordingTile> {
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

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.stop();
      await _player.setSourceDeviceFile(widget.recording.audioFilePath);
      await _player.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy  HH:mm');
    final duration = Duration(seconds: widget.recording.durationSeconds);
    final durationText =
        '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        onTap: widget.onTap,
        leading: _buildLeading(context),
        title: Text(
          dateFormat.format(widget.recording.createdAt),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        subtitle: Text('Duration: $durationText'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: _togglePlayback,
            ),
            if (widget.onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: widget.onDelete,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeading(BuildContext context) {
    if (!widget.recording.isProcessed) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (widget.recording.errorMessage != null) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.error_outline, color: Colors.red),
      );
    }

    final band =
        IeltsBandMapper.mapScoreToBand(widget.recording.result!.overallScore);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _bandColor(band).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          band.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _bandColor(band),
          ),
        ),
      ),
    );
  }

  Color _bandColor(double band) {
    if (band >= 7) return Colors.green.shade700;
    if (band >= 5) return Colors.orange.shade700;
    return Colors.red.shade700;
  }
}
