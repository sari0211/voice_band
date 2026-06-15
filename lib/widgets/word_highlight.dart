import 'package:flutter/material.dart';
import '../models/recording.dart';

class WordHighlight extends StatelessWidget {
  final List<WordDetail> words;

  const WordHighlight({super.key, required this.words});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 6,
      children: words.map((word) => _buildWord(context, word)).toList(),
    );
  }

  Widget _buildWord(BuildContext context, WordDetail word) {
    final color = _wordColor(word);
    return Tooltip(
      message: _tooltipMessage(word),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          word.word,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Color _wordColor(WordDetail word) {
    if (word.errorType == 'Omission') return Colors.red.shade700;
    if (word.errorType == 'Insertion') return Colors.purple.shade700;
    if (word.accuracyScore >= 80) return Colors.green.shade700;
    if (word.accuracyScore >= 50) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  String _tooltipMessage(WordDetail word) {
    final accuracy = word.accuracyScore.toStringAsFixed(0);
    final error = word.errorType ?? 'None';
    return 'Accuracy: $accuracy%\nError: $error';
  }
}
