import 'dart:async';
import 'package:flutter/material.dart';
import '../services/lichess_service.dart';
import '../models/lichess_online_models.dart';
import 'live_game_screen.dart';

class ActiveGamesScreen extends StatefulWidget {
  const ActiveGamesScreen({super.key});

  @override
  State<ActiveGamesScreen> createState() => _ActiveGamesScreenState();
}

class _ActiveGamesScreenState extends State<ActiveGamesScreen> {
  final LichessService _lichessService = LichessService.instance;
  StreamSubscription<LichessEvent>? _eventSubscription;
  List<LichessActiveGame> _activeGames = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadActiveGames();
    _subscribeToEvents();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadActiveGames() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final games = await _lichessService.fetchActiveGames();
      if (!mounted) return;
      setState(() {
        _activeGames = games;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = LichessService.formatError(e);
        _isLoading = false;
      });
    }
  }

  void _subscribeToEvents() {
    try {
      _eventSubscription = _lichessService.streamEvents().listen(
        (event) {
          if (event.type == 'gameStart' || event.type == 'gameFinish') {
            _loadActiveGames();
          }
        },
        onError: (e) {
          debugPrint('Error in active games stream: $e');
        },
      );
    } catch (e) {
      debugPrint('Could not listen to event stream: $e');
    }
  }

  String _formatTimeLeft(int seconds) {
    if (seconds <= 0) return '00:00';
    final minutes = seconds ~/ 60;
    final remainingSecs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSecs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1B29),
      appBar: AppBar(
        title: const Text('Active Games'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadActiveGames,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.white70, fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadActiveGames,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
                          child: const Text('Retry'),
                        )
                      ],
                    ),
                  ),
                )
              : _activeGames.isEmpty
                  ? const Center(
                      child: Text(
                        'No ongoing games found.',
                        style: TextStyle(color: Colors.white38, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _activeGames.length,
                      itemBuilder: (context, index) {
                        final game = _activeGames[index];
                        final isWhite = game.color == 'white';
                        final ratingStr = game.opponentRating != null ? '(${game.opponentRating})' : '';

                        return Card(
                          color: const Color(0xFF2C243E),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.deepPurple.withValues(alpha: 0.1), width: 1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: isWhite ? Colors.white : Colors.black,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white24, width: 1),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Vs  ${game.opponentName} $ratingStr',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: game.isMyTurn
                                            ? Colors.green.withValues(alpha: 0.15)
                                            : Colors.white10,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        game.isMyTurn ? 'Your Turn' : "Their Turn",
                                        style: TextStyle(
                                          color: game.isMyTurn ? Colors.green : Colors.white60,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Speed: ${game.speed.toUpperCase()}',
                                          style: const TextStyle(color: Colors.white60, fontSize: 13),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Time Left: ${_formatTimeLeft(game.secondsLeft)}',
                                          style: const TextStyle(color: Colors.white60, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => LiveGameScreen(gameId: game.gameId),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.deepPurpleAccent,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text('Resume'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
