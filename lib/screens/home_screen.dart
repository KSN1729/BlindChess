import 'package:flutter/material.dart';
import '../widgets/section_title.dart';
import 'game_screen.dart';
import 'stats_screen.dart';
import '../services/lichess_service.dart';
import 'recent_games_screen.dart';
import '../widgets/challenge_bot_dialog.dart';
import 'speech_test_screen.dart';

/// [Why widgets are separated]
/// Separating widgets into different files decomposes large, monolith files into small, single-purpose
/// components. This makes visual layouts modular, easier to maintain, and cleaner to read.
///
/// [Widget reuse]
/// Reusable widgets are building blocks that can be declared once and referenced across different screens
/// (like using [SectionTitle] in both [HomeScreen] and [GameScreen]). This ensures design consistency
/// and drastically reduces code duplication.
///
/// [Constructor communication]
/// Parent widgets communicate with child widgets by passing arguments (like `title`) into their
/// constructor when instantiating them.
///
/// [StatelessWidget]
/// A widget that relies only on configuration properties passed through its constructor. It has no internal,
/// mutable state that changes during its lifecycle.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('BlindChess'),
          actions: [
            IconButton(
              icon: const Icon(Icons.record_voice_over),
              tooltip: 'Speech Test',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SpeechTestScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.bar_chart),
              tooltip: 'Statistics',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StatsScreen()),
                );
              },
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 8.0,
                  ),
                  // Replaced the plain welcome Text widget with our custom reusable SectionTitle widget.
                  child: SectionTitle(title: 'Welcome to BlindChess'),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    'Train your chess memory with Blindfold Mode',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.grid_on,
                    size: 64,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 2,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GameScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Start Game',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildLichessSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLichessSection(BuildContext context) {
    final lichess = LichessService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([
        lichess.isAuthenticatedNotifier,
        lichess.isAuthenticatingNotifier,
        lichess.usernameNotifier,
        lichess.blitzRatingNotifier,
        lichess.rapidRatingNotifier,
        lichess.errorMessageNotifier,
        lichess.gamesPlayedNotifier,
        lichess.winsNotifier,
        lichess.lossesNotifier,
        lichess.drawsNotifier,
      ]),
      builder: (context, _) {
        final isAuthenticated = lichess.isAuthenticated;
        final isAuthenticating = lichess.isAuthenticatingNotifier.value;
        final username = lichess.username;
        final blitz = lichess.blitzRating;
        final rapid = lichess.rapidRating;
        final errorMessage = lichess.errorMessageNotifier.value;
        final games = lichess.gamesPlayed;
        final wins = lichess.wins;
        final losses = lichess.losses;
        final draws = lichess.draws;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: Colors.deepPurple.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.account_balance,
                    color: Colors.deepPurple,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Lichess Companion',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isAuthenticating)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ),
                )
              else if (isAuthenticated) ...[
                Text(
                  'Connected as: $username',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Blitz: ${blitz ?? "N/A"}   |   Rapid: ${rapid ?? "N/A"}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Games: ${games ?? "N/A"}  |  Record: ${wins ?? "0"}W / ${losses ?? "0"}L / ${draws ?? "0"}D',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RecentGamesScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('Recent Games'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const ChallengeBotDialog(),
                    );
                  },
                  icon: const Icon(Icons.smart_toy),
                  label: const Text('Play Lichess Bot'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  key: const ValueKey('play_blindfold_bot_btn'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) =>
                          const ChallengeBotDialog(startWithBlindfold: true),
                    );
                  },
                  icon: const Icon(Icons.visibility_off),
                  label: const Text('Blindfold vs Bot'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => lichess.logout(),
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Disconnect'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ] else if (errorMessage != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => lichess.login(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ] else ...[
                const Text(
                  'Login to challenge friends or bots online.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => lichess.login(),
                  icon: const Icon(Icons.login),
                  label: const Text('Login with Lichess'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
