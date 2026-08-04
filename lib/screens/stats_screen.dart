import 'package:flutter/material.dart';
import '../services/statistics_service.dart';
import '../widgets/section_title.dart';

/// Screen widget displaying aggregated stats, percentages, and fastest win records.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _isLoading = true;
  final StatisticsService _statsService = StatisticsService.instance;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    await _statsService.loadStats();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Presents a reset confirmation dialog.
  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset Statistics?'),
          content: const Text(
            'This will permanently delete all stored games, scores, and records. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });
      await _statsService.clearStats();
      await _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Statistics successfully reset.')),
        );
      }
    }
  }

  Widget _buildStatTile({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        leading: Icon(icon, color: color ?? Colors.deepPurple),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        trailing: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color ?? Colors.deepPurple,
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementsGrid() {
    final badges = [
      (
        id: 'first_win',
        title: 'First Win',
        description: 'Win your first local game (White or Black).',
        isUnlocked: _statsService.whiteWins + _statsService.blackWins >= 1,
        icon: Icons.workspace_premium,
        color: Colors.amber,
      ),
      (
        id: 'minds_eye',
        title: "Mind's Eye",
        description: 'Win a game with Blindfold Mode active.',
        isUnlocked: _statsService.blindfoldWins >= 1,
        icon: Icons.remove_red_eye,
        color: Colors.deepPurpleAccent,
      ),
      (
        id: 'speed_demon',
        title: 'Speed Demon',
        description: 'Win a game in 10 half-moves or fewer.',
        isUnlocked:
            _statsService.fastestWinHalfMoves != null &&
            _statsService.fastestWinHalfMoves! <= 10,
        icon: Icons.speed,
        color: Colors.redAccent,
      ),
      (
        id: 'perfectionist',
        title: 'Perfectionist',
        description: 'Complete a Blindfold game with 100% memory accuracy.',
        isUnlocked:
            _statsService.highestMemoryScore == 100 &&
            _statsService.totalBlindfoldGamesPlayed >= 1,
        icon: Icons.check_circle,
        color: Colors.green,
      ),
      (
        id: 'marathoner',
        title: 'Marathoner',
        description: 'Play 10 or more total games.',
        isUnlocked: _statsService.totalGamesPlayed >= 10,
        icon: Icons.directions_run,
        color: Colors.blueAccent,
      ),
      (
        id: 'consistent',
        title: 'Consistent',
        description: 'Reach a daily streak of 3 or more days.',
        isUnlocked: _statsService.currentStreak >= 3,
        icon: Icons.calendar_month,
        color: Colors.orange,
      ),
      (
        id: 'both_sides',
        title: 'Both Sides',
        description: 'Record at least one win for White and one win for Black.',
        isUnlocked:
            _statsService.whiteWins >= 1 && _statsService.blackWins >= 1,
        icon: Icons.compare_arrows,
        color: Colors.teal,
      ),
    ];

    return Column(
      children: badges.map((badge) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: badge.isUnlocked
                ? Colors.deepPurple.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: badge.isUnlocked
                  ? Colors.deepPurple.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.15),
              width: badge.isUnlocked ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Opacity(
                opacity: badge.isUnlocked ? 1.0 : 0.3,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (badge.isUnlocked ? badge.color : Colors.grey)
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    badge.icon,
                    color: badge.isUnlocked ? badge.color : Colors.grey,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Opacity(
                  opacity: badge.isUnlocked ? 1.0 : 0.5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              badge.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: badge.isUnlocked
                                    ? Colors.black87
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                          if (badge.isUnlocked) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified,
                              color: Colors.green,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        badge.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: badge.isUnlocked
                              ? Colors.grey[700]
                              : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                badge.isUnlocked ? 'Unlocked' : 'Locked',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: badge.isUnlocked ? Colors.green : Colors.grey,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final fastestWinStr = _statsService.fastestWinHalfMoves != null
        ? '${_statsService.fastestWinHalfMoves} half-moves'
        : 'N/A';

    final hasBlindfoldData = _statsService.totalBlindfoldGamesPlayed > 0;
    final highestAccuracyStr = hasBlindfoldData
        ? '${_statsService.highestMemoryScore}%'
        : 'N/A';
    final averageAccuracyStr = hasBlindfoldData
        ? '${_statsService.averageMemoryAccuracy.toStringAsFixed(1)}%'
        : 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lifetime Statistics'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            tooltip: 'Reset Stats',
            onPressed: _confirmReset,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top Summary Card with Gradient background
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.deepPurple, Colors.indigo],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'TOTAL GAMES COMPLETED',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_statsService.totalGamesPlayed}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.flash_on,
                            color: Colors.amber,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Fastest Win: $fastestWinStr',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            color: Colors.orangeAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Streak: ${_statsService.currentStreak} ${_statsService.currentStreak == 1 ? 'day' : 'days'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Game Outcomes Section
            const SectionTitle(title: 'Game Outcomes'),
            const SizedBox(height: 8),
            _buildStatTile(
              icon: Icons.emoji_events,
              label: 'White Wins',
              value: '${_statsService.whiteWins}',
              color: Colors.grey[700],
            ),
            _buildStatTile(
              icon: Icons.emoji_events_outlined,
              label: 'Black Wins',
              value: '${_statsService.blackWins}',
              color: Colors.black,
            ),
            _buildStatTile(
              icon: Icons.handshake,
              label: 'Draws',
              value: '${_statsService.draws}',
              color: Colors.blueGrey,
            ),
            const SizedBox(height: 24),

            // Memory Performance Section
            const SectionTitle(title: 'Memory Performance'),
            const SizedBox(height: 8),
            _buildStatTile(
              icon: Icons.visibility_off,
              label: 'Blindfold Games Played',
              value: '${_statsService.totalBlindfoldGamesPlayed}',
            ),
            _buildStatTile(
              icon: Icons.language,
              label: 'Online Games Played',
              value: '${_statsService.onlineGamesPlayed}',
              color: Colors.indigo,
            ),
            _buildStatTile(
              icon: Icons
                  .wifi_off_outlined, // Wait, wifi_off? No, wifi or language or cloud is better for online. Let's use language or cloud
              label: 'Online Blindfold Games',
              value: '${_statsService.onlineBlindfoldGamesPlayed}',
              color: Colors.deepPurple,
            ),
            _buildStatTile(
              icon: Icons.star,
              label: 'Highest Memory Accuracy',
              value: highestAccuracyStr,
              color: Colors.orange,
            ),
            _buildStatTile(
              icon: Icons.show_chart,
              label: 'Average Memory Accuracy',
              value: averageAccuracyStr,
              color: Colors.teal,
            ),
            const SizedBox(height: 24),

            // Achievements Section
            const SectionTitle(title: 'Achievements'),
            const SizedBox(height: 12),
            _buildAchievementsGrid(),
            const SizedBox(height: 32),

            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Game'),
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
