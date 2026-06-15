import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/recording_session_provider.dart';

class RecordingOverlay extends StatelessWidget {
  final VoidCallback onStopped;

  const RecordingOverlay({super.key, required this.onStopped});

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingSessionProvider>(
      builder: (context, session, _) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                24, 24, 24, MediaQuery.of(context).viewPadding.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulsing mic icon
                _PulsingMic(isRecording: session.isRecording),
                const SizedBox(height: 16),
                // Timer
                Text(
                  '${session.timerText} / ${session.maxTimerText}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontFeatures: [const FontFeature.tabularFigures()],
                      ),
                ),
                const SizedBox(height: 12),
                // Progress bar
                LinearProgressIndicator(
                  value: session.progress,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 24),
                // Stop button
                SizedBox(
                  width: 72,
                  height: 72,
                  child: FloatingActionButton(
                    onPressed: () async {
                      await session.stopRecording();
                      onStopped();
                    },
                    backgroundColor: Colors.red,
                    child:
                        const Icon(Icons.stop, size: 36, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to stop recording',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PulsingMic extends StatefulWidget {
  final bool isRecording;
  const _PulsingMic({required this.isRecording});

  @override
  State<_PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<_PulsingMic>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isRecording) {
      return const Icon(Icons.mic, size: 64, color: Colors.grey);
    }
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withValues(alpha: 0.2),
            ),
            child: const Icon(Icons.mic, size: 48, color: Colors.red),
          ),
        );
      },
    );
  }
}
