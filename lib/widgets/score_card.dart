import 'package:flutter/material.dart';

class ScoreCard extends StatelessWidget {
  final String label;
  final double score;
  final IconData icon;
  final bool displayAsWpm;
  final bool displayAsCount;

  const ScoreCard({
    super.key,
    required this.label,
    required this.score,
    required this.icon,
    this.displayAsWpm = false,
    this.displayAsCount = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayText = displayAsWpm
        ? score.toStringAsFixed(0)
        : displayAsCount
            ? '${score.toInt()}'
            : score.toStringAsFixed(0);

    final suffix = displayAsWpm ? ' wpm' : '';
    final color = displayAsWpm
        ? _wpmColor(score)
        : displayAsCount
            ? _pauseColor(score)
            : _scoreColor(score);

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              displayText,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (suffix.isNotEmpty)
              Text(
                suffix,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 80) return Colors.green.shade700;
    if (score >= 60) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  Color _wpmColor(double wpm) {
    if (wpm >= 110 && wpm <= 160) return Colors.green.shade700;
    if (wpm >= 90 && wpm <= 180) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  Color _pauseColor(double count) {
    if (count <= 2) return Colors.green.shade700;
    if (count <= 5) return Colors.orange.shade700;
    return Colors.red.shade700;
  }
}
