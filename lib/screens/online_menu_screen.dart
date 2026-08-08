import 'package:flutter/material.dart';
import '../services/lichess_service.dart';
import '../models/lichess_connection_state.dart';
import '../models/lichess_online_models.dart';
import 'challenges_screen.dart';
import 'active_games_screen.dart';

class OnlineMenuScreen extends StatefulWidget {
  const OnlineMenuScreen({super.key});

  @override
  State<OnlineMenuScreen> createState() => _OnlineMenuScreenState();
}

class _OnlineMenuScreenState extends State<OnlineMenuScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final LichessService _lichessService;

  @override
  void initState() {
    super.initState();
    _lichessService = LichessService.instance;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getStatusColor(LichessConnectionState state) {
    switch (state) {
      case LichessConnectionState.connected:
        return Colors.green;
      case LichessConnectionState.connecting:
      case LichessConnectionState.reconnecting:
        return Colors.amber;
      case LichessConnectionState.networkUnavailable:
        return Colors.red;
      case LichessConnectionState.authenticationFailed:
      case LichessConnectionState.authenticationExpired:
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(LichessConnectionState state) {
    switch (state) {
      case LichessConnectionState.connected:
        return 'Connected';
      case LichessConnectionState.connecting:
        return 'Connecting...';
      case LichessConnectionState.reconnecting:
        return 'Reconnecting...';
      case LichessConnectionState.networkUnavailable:
        return 'Offline';
      case LichessConnectionState.authenticationFailed:
        return 'Auth Failed';
      case LichessConnectionState.authenticationExpired:
        return 'Session Expired';
      default:
        return 'Disconnected';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1B29), // Rich midnight background
      appBar: AppBar(
        title: const Text('Online Gameplay'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          _lichessService.sessionManager.connectionStateNotifier,
          _lichessService.usernameNotifier,
          _lichessService.blitzRatingNotifier,
          _lichessService.rapidRatingNotifier,
        ]),
        builder: (context, _) {
          final state = _lichessService.sessionManager.connectionState;
          final username = _lichessService.username ?? 'Anonymous';
          final blitz = _lichessService.blitzRating;
          final rapid = _lichessService.rapidRating;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Connection Indicator Card
                  Card(
                    color: const Color(0xFF2C243E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: Colors.deepPurple.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              final alphaVal = state == LichessConnectionState.connecting ||
                                      state == LichessConnectionState.reconnecting
                                  ? (0.3 + 0.7 * _pulseController.value)
                                  : 1.0;
                              return Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _getStatusColor(state).withValues(alpha: alphaVal),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _getStatusColor(state).withValues(alpha: 0.5),
                                      blurRadius: 8 * _pulseController.value,
                                      spreadRadius: 2 * _pulseController.value,
                                    )
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  username,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getStatusText(state),
                                  style: TextStyle(
                                    color: _getStatusColor(state),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (blitz != null || rapid != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (blitz != null)
                                  Text(
                                    '⚡ Blitz: $blitz',
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                if (rapid != null)
                                  Text(
                                    '⏱️ Rapid: $rapid',
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Menu Action Grid/Cards
                  _buildMenuCard(
                    icon: Icons.add_circle_outline,
                    title: 'Create Challenge',
                    subtitle: 'Create open link or challenge a friend',
                    color: Colors.deepPurpleAccent,
                    onTap: state == LichessConnectionState.connected
                        ? _showCreateChallengeSheet
                        : null,
                  ),
                  const SizedBox(height: 16),

                  _buildMenuCard(
                    icon: Icons.mail_outline,
                    title: 'Challenges Inbox',
                    subtitle: 'Accept or decline pending challenges',
                    color: Colors.blueAccent,
                    onTap: state == LichessConnectionState.connected
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ChallengesScreen()),
                            )
                        : null,
                  ),
                  const SizedBox(height: 16),

                  _buildMenuCard(
                    icon: Icons.play_arrow_outlined,
                    title: 'Active Games',
                    subtitle: 'Resume your active unfinished games',
                    color: Colors.greenAccent,
                    onTap: state == LichessConnectionState.connected
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ActiveGamesScreen()),
                            )
                        : null,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final bool isEnabled = onTap != null;

    return Card(
      color: isEnabled ? const Color(0xFF2C243E) : const Color(0xFF2C243E).withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isEnabled ? Colors.deepPurple.withValues(alpha: 0.2) : Colors.transparent,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isEnabled ? Colors.white : Colors.white38,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isEnabled ? Colors.white60 : Colors.white24,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: isEnabled ? Colors.white30 : Colors.white12,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateChallengeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF231F33),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return const _CreateChallengeSheet();
      },
    );
  }
}

class _CreateChallengeSheet extends StatefulWidget {
  const _CreateChallengeSheet();

  @override
  State<_CreateChallengeSheet> createState() => _CreateChallengeSheetState();
}

class _CreateChallengeSheetState extends State<_CreateChallengeSheet> {
  bool _isRated = false;
  String _color = 'random'; // 'white', 'black', 'random'
  int _baseMinutes = 10;
  int _incrementSeconds = 0;
  bool _isDirectChallenge = false;
  final _opponentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _opponentController.dispose();
    super.dispose();
  }

  void _submit() async {
    final opponent = _opponentController.text.trim();
    if (_isDirectChallenge && opponent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an opponent username.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final clockLimit = _baseMinutes * 60;
      final clockIncrement = _incrementSeconds;

      LichessChallenge challenge;
      if (_isDirectChallenge) {
        challenge = await LichessService.instance.createOpponentChallenge(
          opponent: opponent,
          clockLimit: clockLimit,
          clockIncrement: clockIncrement,
          color: _color,
          rated: _isRated,
        );
      } else {
        challenge = await LichessService.instance.createOpenChallenge(
          clockLimit: clockLimit,
          clockIncrement: clockIncrement,
          color: _color,
          rated: _isRated,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);

      // Display challenge information/link dialog
      showDialog(
        context: context,
        builder: (context) {
          final isLink = challenge.url != null;
          return AlertDialog(
            backgroundColor: const Color(0xFF2C243E),
            title: Text(
              _isDirectChallenge ? 'Challenge Sent' : 'Challenge Link Created',
              style: const TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isDirectChallenge
                      ? 'Direct challenge sent to: $opponent\n\nWaiting for acceptance.'
                      : 'Share this link to invite an opponent:',
                  style: const TextStyle(color: Colors.white70),
                ),
                if (isLink) ...[
                  const SizedBox(height: 12),
                  SelectableText(
                    challenge.url!,
                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: TextStyle(color: Colors.white54)),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LichessService.formatError(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Custom Game Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white60),
              )
            ],
          ),
          const SizedBox(height: 16),

          // Rated vs Casual
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Rated Match', style: TextStyle(color: Colors.white70, fontSize: 15)),
              Switch(
                value: _isRated,
                activeTrackColor: Colors.deepPurpleAccent,
                onChanged: (val) => setState(() => _isRated = val),
              ),
            ],
          ),
          const Divider(color: Colors.white10),

          // Direct Challenge vs Open Link
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Challenge Specific User', style: TextStyle(color: Colors.white70, fontSize: 15)),
              Switch(
                value: _isDirectChallenge,
                activeTrackColor: Colors.deepPurpleAccent,
                onChanged: (val) => setState(() => _isDirectChallenge = val),
              ),
            ],
          ),
          if (_isDirectChallenge) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _opponentController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter Lichess username',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF2C243E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
          const Divider(color: Colors.white10),

          // Time limit Selection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Minutes per side', style: TextStyle(color: Colors.white70, fontSize: 15)),
              DropdownButton<int>(
                dropdownColor: const Color(0xFF2C243E),
                value: _baseMinutes,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                items: [1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120].map((m) {
                  return DropdownMenuItem<int>(value: m, child: Text('$m min'));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _baseMinutes = val);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Increment Selection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Increment seconds', style: TextStyle(color: Colors.white70, fontSize: 15)),
              DropdownButton<int>(
                dropdownColor: const Color(0xFF2C243E),
                value: _incrementSeconds,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                items: [0, 1, 2, 3, 5, 8, 10, 15, 20, 30, 60].map((s) {
                  return DropdownMenuItem<int>(value: s, child: Text('$s sec'));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _incrementSeconds = val);
                },
              ),
            ],
          ),
          const Divider(color: Colors.white10),

          // Color Selection
          const Text('Your Color Preference', style: TextStyle(color: Colors.white70, fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildColorButton('white', 'White', Icons.circle, Colors.white),
              _buildColorButton('random', 'Random', Icons.help_outline, Colors.deepPurpleAccent),
              _buildColorButton('black', 'Black', Icons.circle, Colors.black),
            ],
          ),
          const SizedBox(height: 24),

          // Submit Button
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Create Game Challenge', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildColorButton(String value, String label, IconData icon, Color iconColor) {
    final isSelected = _color == value;
    return InkWell(
      onTap: () => setState(() => _color = value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.deepPurpleAccent : Colors.white12,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
