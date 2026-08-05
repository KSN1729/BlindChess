import 'dart:async';
import 'package:flutter/material.dart';
import '../services/voice_pipeline_service.dart';

/// Reusable premium control providing speech-to-text input with custom pulsing glow indicator.
class VoiceCommandWidget extends StatefulWidget {
  final Function(String command, {double? sttConfidence}) onCommand;
  final bool isEnabled;

  const VoiceCommandWidget({
    super.key,
    required this.onCommand,
    this.isEnabled = true,
  });

  @override
  State<VoiceCommandWidget> createState() => _VoiceCommandWidgetState();
}

class _VoiceCommandWidgetState extends State<VoiceCommandWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  String _recognizedText = '';
  StreamSubscription<VoiceState>? _stateSubscription;
  StreamSubscription<String>? _textSubscription;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Sync pulse animation with voice pipeline state transitions
    _stateSubscription = VoicePipelineService.instance.onStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          final isListening = state == VoiceState.listening || state == VoiceState.undoWindow;
          if (isListening) {
            _pulseController.repeat(reverse: true);
          } else {
            _pulseController.stop();
          }
        });
      }
    });

    // Sync real-time recognized text preview
    _textSubscription = VoicePipelineService.instance.onRecognizedTextChanged.listen((text) {
      if (mounted) {
        setState(() {
          _recognizedText = text;
        });
      }
    });

    final isListening = VoicePipelineService.instance.state == VoiceState.listening ||
        VoicePipelineService.instance.state == VoiceState.undoWindow;
    if (isListening) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _textSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (!widget.isEnabled) return;
    await VoicePipelineService.instance.toggleListening();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pipeline = VoicePipelineService.instance;
    final isListening = pipeline.state == VoiceState.listening || pipeline.state == VoiceState.undoWindow;

    String instructionText = 'Tap microphone and speak move (e.g. "e2 to e4", "knight f3")';
    if (pipeline.state == VoiceState.processing) {
      instructionText = 'Processing command...';
    } else if (pipeline.state == VoiceState.speakingFeedback) {
      instructionText = 'Speaking...';
    } else if (!widget.isEnabled) {
      instructionText = 'Voice command disabled during opponent turn';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: isDark
              ? Colors.deepPurple.withValues(alpha: 0.1)
              : Colors.deepPurple.withValues(alpha: 0.05),
          border: Border.all(
            color: isListening
                ? Colors.deepPurple
                : Colors.deepPurple.withValues(alpha: 0.2),
            width: isListening ? 2.0 : 1.0,
          ),
          boxShadow: isListening
              ? [
                  BoxShadow(
                    color: Colors.deepPurple.withValues(alpha: 0.2),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isListening ? 'Listening...' : 'Voice Command',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isListening
                          ? Colors.deepPurple
                          : theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _recognizedText.isNotEmpty
                          ? '"$_recognizedText"'
                          : instructionText,
                      key: ValueKey(
                        _recognizedText.isEmpty ? instructionText : 'recognized',
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: _recognizedText.isNotEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                        color: _recognizedText.isNotEmpty
                            ? (isDark
                                  ? Colors.deepPurple[200]
                                  : Colors.deepPurple[900])
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                if (isListening)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 56 * _pulseAnimation.value,
                        height: 56 * _pulseAnimation.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.deepPurple.withValues(alpha: 0.15),
                        ),
                      );
                    },
                  ),
                Material(
                  color: widget.isEnabled
                      ? (isListening
                            ? Colors.deepPurple
                            : Colors.deepPurple[700])
                      : Colors.grey[400],
                  shape: const CircleBorder(),
                  elevation: isListening ? 6 : 2,
                  child: InkWell(
                    key: const ValueKey('mic_button'),
                    onTap: widget.isEnabled ? _toggleListening : null,
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: 50,
                      height: 50,
                      child: Icon(Icons.mic, color: Colors.white, size: 26),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
