import 'dart:math';
import 'package:flutter/material.dart';
import '../data/questions_data.dart';
import 'history_screen.dart';
import 'question_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openRandomQuestion(BuildContext context) {
    if (ieltsQuestions.isEmpty) return;
    final question = ieltsQuestions[Random().nextInt(ieltsQuestions.length)];
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuestionScreen(question: question)),
    );
  }

  void _openHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Band'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CircleButton(
              icon: Icons.play_arrow,
              label: 'Play',
              color: Theme.of(context).colorScheme.primary,
              onTap: () => _openRandomQuestion(context),
            ),
            const SizedBox(width: 32),
            _CircleButton(
              icon: Icons.history,
              label: 'History',
              color: Theme.of(context).colorScheme.secondary,
              onTap: () => _openHistory(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 110,
              height: 110,
              child: Icon(icon, size: 56, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
