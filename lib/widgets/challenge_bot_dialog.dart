import 'package:flutter/material.dart';
import '../services/lichess_service.dart';
import '../services/settings_service.dart';
import '../screens/live_game_screen.dart';

class TimeControlPreset {
  final String label;
  final int limit;
  final int increment;
  const TimeControlPreset(this.label, this.limit, this.increment);
}

class ChallengeBotDialog extends StatefulWidget {
  final bool startWithBlindfold;

  const ChallengeBotDialog({super.key, this.startWithBlindfold = false});

  @override
  State<ChallengeBotDialog> createState() => _ChallengeBotDialogState();
}

class _ChallengeBotDialogState extends State<ChallengeBotDialog> {
  double _level = 1.0;
  String _color = 'random'; // 'white', 'black', 'random'

  static const List<TimeControlPreset> _presets = [
    TimeControlPreset('3+0', 180, 0),
    TimeControlPreset('5+0', 300, 0),
    TimeControlPreset('10+0', 600, 0),
    TimeControlPreset('15+10', 900, 10),
  ];

  int _selectedPresetIndex = 1; // Default to 5+0
  bool _isPending = false;

  late bool _isBlindfoldMode;
  late BlindfoldDifficulty _blindfoldDifficulty;

  @override
  void initState() {
    super.initState();
    _isBlindfoldMode = widget.startWithBlindfold;
    _blindfoldDifficulty = SettingsService.instance.blindfoldDifficulty;
  }

  Future<void> _startChallenge() async {
    setState(() {
      _isPending = true;
    });

    final preset = _presets[_selectedPresetIndex];

    try {
      final gameId = await LichessService.instance.challengeAi(
        level: _level.toInt(),
        clockLimit: preset.limit,
        clockIncrement: preset.increment,
        color: _color,
      );

      if (mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LiveGameScreen(
              gameId: gameId,
              initialBlindfoldMode: _isBlindfoldMode,
              initialBlindfoldDifficulty: _isBlindfoldMode
                  ? _blindfoldDifficulty
                  : null,
            ),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Challenge created successfully! Game ID: $gameId'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.smart_toy, color: Colors.deepPurple),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Challenge Lichess AI',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: _isPending
          ? const SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Creating game on Lichess...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Bot Level Slider ---
                  Text(
                    'Bot Difficulty Level: ${_level.toInt()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Slider(
                    value: _level,
                    min: 1.0,
                    max: 8.0,
                    divisions: 7,
                    label: 'Level ${_level.toInt()}',
                    activeColor: Colors.deepPurple,
                    onChanged: (val) {
                      setState(() {
                        _level = val;
                      });
                    },
                  ),
                  const Divider(),
                  const SizedBox(height: 8),

                  // --- Color Selector ---
                  const Text(
                    'Your Color:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceEvenly,
                    children: [
                      ChoiceChip(
                        label: const Text('White'),
                        selected: _color == 'white',
                        selectedColor: Colors.deepPurple.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: _color == 'white' ? Colors.deepPurple : null,
                          fontWeight: _color == 'white'
                              ? FontWeight.bold
                              : null,
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _color = 'white');
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Random'),
                        selected: _color == 'random',
                        selectedColor: Colors.deepPurple.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: _color == 'random' ? Colors.deepPurple : null,
                          fontWeight: _color == 'random'
                              ? FontWeight.bold
                              : null,
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _color = 'random');
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Black'),
                        selected: _color == 'black',
                        selectedColor: Colors.deepPurple.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: _color == 'black' ? Colors.deepPurple : null,
                          fontWeight: _color == 'black'
                              ? FontWeight.bold
                              : null,
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _color = 'black');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // --- Time Presets ---
                  const Text(
                    'Time Control Preset:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_presets.length, (index) {
                      final p = _presets[index];
                      final isSelected = _selectedPresetIndex == index;
                      return ChoiceChip(
                        label: Text(p.label),
                        selected: isSelected,
                        selectedColor: Colors.deepPurple.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.deepPurple : null,
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedPresetIndex = index);
                          }
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // --- Blindfold Mode Toggle ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Blindfold Mode:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Switch(
                        key: const ValueKey('dialog_blindfold_switch'),
                        value: _isBlindfoldMode,
                        onChanged: (val) {
                          setState(() {
                            _isBlindfoldMode = val;
                          });
                        },
                        activeThumbColor: Colors.deepPurple,
                      ),
                    ],
                  ),

                  if (_isBlindfoldMode) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Blindfold Difficulty:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceEvenly,
                      children: [
                        ChoiceChip(
                          key: const ValueKey('dialog_chip_easy'),
                          label: const Text('Easy'),
                          selected:
                              _blindfoldDifficulty == BlindfoldDifficulty.easy,
                          selectedColor: Colors.deepPurple.withValues(
                            alpha: 0.2,
                          ),
                          labelStyle: TextStyle(
                            color:
                                _blindfoldDifficulty == BlindfoldDifficulty.easy
                                ? Colors.deepPurple
                                : null,
                            fontWeight:
                                _blindfoldDifficulty == BlindfoldDifficulty.easy
                                ? FontWeight.bold
                                : null,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(
                                () => _blindfoldDifficulty =
                                    BlindfoldDifficulty.easy,
                              );
                            }
                          },
                        ),
                        ChoiceChip(
                          key: const ValueKey('dialog_chip_medium'),
                          label: const Text('Medium'),
                          selected:
                              _blindfoldDifficulty ==
                              BlindfoldDifficulty.medium,
                          selectedColor: Colors.deepPurple.withValues(
                            alpha: 0.2,
                          ),
                          labelStyle: TextStyle(
                            color:
                                _blindfoldDifficulty ==
                                    BlindfoldDifficulty.medium
                                ? Colors.deepPurple
                                : null,
                            fontWeight:
                                _blindfoldDifficulty ==
                                    BlindfoldDifficulty.medium
                                ? FontWeight.bold
                                : null,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(
                                () => _blindfoldDifficulty =
                                    BlindfoldDifficulty.medium,
                              );
                            }
                          },
                        ),
                        ChoiceChip(
                          key: const ValueKey('dialog_chip_hard'),
                          label: const Text('Hard'),
                          selected:
                              _blindfoldDifficulty == BlindfoldDifficulty.hard,
                          selectedColor: Colors.deepPurple.withValues(
                            alpha: 0.2,
                          ),
                          labelStyle: TextStyle(
                            color:
                                _blindfoldDifficulty == BlindfoldDifficulty.hard
                                ? Colors.deepPurple
                                : null,
                            fontWeight:
                                _blindfoldDifficulty == BlindfoldDifficulty.hard
                                ? FontWeight.bold
                                : null,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(
                                () => _blindfoldDifficulty =
                                    BlindfoldDifficulty.hard,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
      actions: _isPending
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: _startChallenge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Start Game'),
              ),
            ],
    );
  }
}
