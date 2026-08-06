import 'package:flutter/material.dart';
import '../services/accessibility_settings_service.dart';
import '../services/tts_service.dart';

class AccessibilitySettingsScreen extends StatelessWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AccessibilitySettingsService.instance;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Accessibility Settings'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: ListenableBuilder(
          listenable: Listenable.merge([
            service.speechEnabledNotifier,
            service.speechRateNotifier,
            service.pitchNotifier,
            service.volumeNotifier,
            service.verbosityNotifier,
            service.audioFeedbackEnabledNotifier,
            service.hapticFeedbackEnabledNotifier,
          ]),
          builder: (context, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionHeader(context, 'Speech Settings', Icons.record_voice_over),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        children: [
                          SwitchListTile(
                            secondary: const Icon(Icons.volume_up, color: Colors.deepPurple),
                            title: const Text('Speech Output Enabled'),
                            subtitle: const Text('Announces moves and game events aloud'),
                            value: service.speechEnabled,
                            onChanged: (val) => service.setSpeechEnabled(val),
                          ),
                          if (service.speechEnabled) ...[
                            const Divider(height: 1),
                            _buildSliderTile(
                              title: 'Speech Rate',
                              subtitle: '${(service.speechRate * 100).toInt()}% speed',
                              value: service.speechRate,
                              min: 0.1,
                              max: 1.0,
                              onChanged: (val) => service.setSpeechRate(val),
                            ),
                            const Divider(height: 1),
                            _buildSliderTile(
                              title: 'Pitch',
                              subtitle: '${(service.pitch * 100).toInt()}% pitch',
                              value: service.pitch,
                              min: 0.5,
                              max: 2.0,
                              onChanged: (val) => service.setPitch(val),
                            ),
                            const Divider(height: 1),
                            _buildSliderTile(
                              title: 'Volume',
                              subtitle: '${(service.volume * 100).toInt()}% volume',
                              value: service.volume,
                              min: 0.0,
                              max: 1.0,
                              onChanged: (val) => service.setVolume(val),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.menu_book, color: Colors.deepPurple),
                              title: const Text('Verbosity Level'),
                              subtitle: Text(service.verbosity.name.toUpperCase()),
                              trailing: DropdownButton<VerbosityLevel>(
                                value: service.verbosity,
                                underline: const SizedBox(),
                                onChanged: (VerbosityLevel? newLevel) {
                                  if (newLevel != null) {
                                    service.setVerbosity(newLevel);
                                  }
                                },
                                items: VerbosityLevel.values.map((level) {
                                  return DropdownMenuItem<VerbosityLevel>(
                                    value: level,
                                    child: Text(level.name.toUpperCase()),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader(context, 'Feedback & Sound', Icons.touch_app),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        children: [
                          SwitchListTile(
                            secondary: const Icon(Icons.music_note, color: Colors.deepPurple),
                            title: const Text('Audio Feedback'),
                            subtitle: const Text('Plays optional chess sound effects'),
                            value: service.audioFeedbackEnabled,
                            onChanged: (val) => service.setAudioFeedbackEnabled(val),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: const Icon(Icons.vibration, color: Colors.deepPurple),
                            title: const Text('Haptic Feedback'),
                            subtitle: const Text('Vibrates on moves, checks, and errors'),
                            value: service.hapticFeedbackEnabled,
                            onChanged: (val) => service.setHapticFeedbackEnabled(val),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (service.speechEnabled)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      icon: const Icon(Icons.replay),
                      label: const Text(
                        'Repeat Last Announcement',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => TtsService.instance.repeatLastAnnouncement(),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepPurple, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            activeColor: Colors.deepPurple,
            inactiveColor: Colors.deepPurple.withValues(alpha: 0.2),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
