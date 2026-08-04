import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import '../services/speech_synthesis_service.dart';

class SpeechTestScreen extends StatefulWidget {
  const SpeechTestScreen({super.key});

  @override
  State<SpeechTestScreen> createState() => _SpeechTestScreenState();
}

class _SpeechTestScreenState extends State<SpeechTestScreen> {
  final TextEditingController _controller = TextEditingController(text: 'pawn to e4');
  bool _isLoading = false;
  String _status = 'Idle';
  String? _generatedPath;
  Map<String, dynamic>? _metadata;

  final List<String> _examples = [
    'pawn to e4',
    'knight to f3',
    'bishop takes knight on c6',
    'queen to h5 giving check',
    'rook to h8 delivering checkmate',
    'castle kingside',
    'pawn to e8 promote to queen',
    'rook from a to d1',
    'move is invalid',
  ];

  Future<void> _generateAudio() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _status = 'Generating...';
      _generatedPath = null;
      _metadata = null;
    });

    final path = await SpeechSynthesisService.instance.generateSpeech(text);

    setState(() {
      _isLoading = false;
      if (path != null) {
        _generatedPath = path;
        _status = 'Success: WAV Generated';
        // Attempt to read the JSON sidecar to load metadata details
        _loadMetadata(path);
      } else {
        _status = 'Error: Generation Failed';
      }
    });
  }

  void _loadMetadata(String wavPath) {
    try {
      final jsonPath = '$wavPath.json';
      final file = File(jsonPath);
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        setState(() {
          _metadata = jsonDecode(content) as Map<String, dynamic>;
        });
      }
    } catch (e) {
      debugPrint('Error loading sidecar JSON: $e');
    }
  }

  Future<void> _playAudio() async {
    if (_generatedPath == null) return;
    setState(() {
      _status = 'Playing...';
    });
    await SpeechSynthesisService.instance.play(_generatedPath!);
    setState(() {
      _status = 'Finished playing';
    });
  }

  Future<void> _speakDirectly() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _status = 'Synthesizing & Playing...';
      _generatedPath = null;
      _metadata = null;
    });

    final path = await SpeechSynthesisService.instance.generateSpeech(text);

    setState(() {
      _isLoading = false;
    });

    if (path != null) {
      setState(() {
        _generatedPath = path;
        _status = 'Speak completed';
        _loadMetadata(path);
      });
      await SpeechSynthesisService.instance.play(path);
    } else {
      setState(() {
        _status = 'Error: Generation Failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Speech Synthesis Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.deepPurple.withValues(alpha: 0.15)),
              ),
              color: Colors.deepPurple.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.record_voice_over, size: 48, color: Colors.deepPurple),
                    const SizedBox(height: 12),
                    Text(
                      'Offline Piper TTS Engine',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This screen calls the local Python Piper ONNX voice synthesis pipeline asynchronously and plays resampled 16kHz WAV outputs.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Text Input
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Enter Chess Phrase to Speak',
                hintText: 'e.g. pawn to e4',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _controller.clear(),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Controls
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _generateAudio,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.settings),
                    label: const Text('Generate WAV'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _generatedPath == null ? null : _playAudio,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play Audio'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _speakDirectly,
              icon: const Icon(Icons.volume_up),
              label: const Text('Speak (Generate & Play)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),

            // Status Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pipeline Status:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isLoading
                                ? Colors.orange.withValues(alpha: 0.1)
                                : _status.contains('Success')
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _status,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _isLoading
                                  ? Colors.orange
                                  : _status.contains('Success')
                                      ? Colors.green
                                      : Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_generatedPath != null) ...[
                      const Divider(height: 24),
                      const Text(
                        'File Path:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        _generatedPath!,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                      ),
                    ],
                    if (_metadata != null) ...[
                      const Divider(height: 24),
                      const Text(
                        'WAV Metadata Sidecar:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      _buildMetaRow('Duration', '${_metadata!['duration']?.toStringAsFixed(3)}s'),
                      _buildMetaRow('Sample Rate', '${_metadata!['sampleRate']} Hz'),
                      _buildMetaRow('Speaker ID', '${_metadata!['speakerId']}'),
                      _buildMetaRow('Checksum', '${_metadata!['checksum']?.substring(0, 16)}...'),
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Pre-configured Chess Examples List
            const Text(
              'Select Preset Chess Example:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _examples.length,
              itemBuilder: (context, idx) {
                final ex = _examples[idx];
                return ListTile(
                  title: Text(ex),
                  dense: true,
                  leading: const Icon(Icons.chat_bubble_outline, size: 16),
                  onTap: () {
                    setState(() {
                      _controller.text = ex;
                    });
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
