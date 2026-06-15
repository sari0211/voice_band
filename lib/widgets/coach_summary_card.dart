import 'package:flutter/material.dart';
import '../models/recording.dart';

class CoachSummaryCard extends StatelessWidget {
  final CoachSummary summary;

  const CoachSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'AI Coach Summary',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            if (summary.overall.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                summary.overall,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
            if (summary.strengths.isNotEmpty) ...[
              const SizedBox(height: 16),
              _section(
                context,
                title: 'What was good',
                color: Colors.green.shade700,
                icon: Icons.check_circle,
                items: summary.strengths,
              ),
            ],
            if (summary.weaknesses.isNotEmpty) ...[
              const SizedBox(height: 12),
              _section(
                context,
                title: 'What to improve',
                color: Colors.orange.shade800,
                icon: Icons.error_outline,
                items: summary.weaknesses,
              ),
            ],
            if (summary.tips.isNotEmpty) ...[
              const SizedBox(height: 12),
              _section(
                context,
                title: 'How to practice',
                color: Theme.of(context).colorScheme.primary,
                icon: Icons.lightbulb_outline,
                items: summary.tips,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required Color color,
    required IconData icon,
    required List<String> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 6),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
