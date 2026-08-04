import 'package:flutter/material.dart';
import '../models/lichess_game.dart';
import '../services/lichess_service.dart';
import 'pgn_replay_screen.dart';

/// Screen listing recent games played by the authenticated Lichess user.
class RecentGamesScreen extends StatefulWidget {
  const RecentGamesScreen({super.key});

  @override
  State<RecentGamesScreen> createState() => _RecentGamesScreenState();
}

class _RecentGamesScreenState extends State<RecentGamesScreen> {
  bool _isLoading = true;
  String? _error;
  List<LichessGame> _games = [];

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  /// Fetches recent user games from LichessService.
  Future<void> _loadGames() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final gamesList = await LichessService.instance.fetchRecentGames(max: 15);
      if (mounted) {
        setState(() {
          _games = gamesList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Helper to format date cleanly without external package dependencies.
  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Resolves the text color based on game outcome.
  Color _getResultColor(String result) {
    if (result == 'Win') return Colors.green;
    if (result == 'Loss') return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Lichess Games'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Failed to load games:\n$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.red),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadGames,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
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

    if (_games.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_toggle_off, color: Colors.grey[400], size: 64),
              const SizedBox(height: 16),
              const Text(
                'No recent games found on this Lichess account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _games.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final game = _games[index];
        final outcomeColor = _getResultColor(game.result);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: outcomeColor.withValues(alpha: 0.1),
              child: Text(
                game.result[0],
                style: TextStyle(
                  color: outcomeColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              'vs. ${game.opponentUsername}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Played as ${game.colorPlayed}  |  ${_formatDate(game.date)}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PgnReplayScreen(game: game),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Dialog overlay to load and display raw PGN content for a selected game.
class PgnDialog extends StatefulWidget {
  final LichessGame game;

  const PgnDialog({super.key, required this.game});

  @override
  State<PgnDialog> createState() => _PgnDialogState();
}

class _PgnDialogState extends State<PgnDialog> {
  bool _isLoading = true;
  String? _pgn;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPgn();
  }

  /// Loads the PGN string. Uses model cache if available, else fetches lazily.
  Future<void> _loadPgn() async {
    if (widget.game.pgn != null) {
      setState(() {
        _pgn = widget.game.pgn;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pgnData = await LichessService.instance.fetchGamePgn(
        widget.game.id,
      );
      widget.game.pgn = pgnData; // Cache the result
      if (mounted) {
        setState(() {
          _pgn = pgnData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'PGN details: vs ${widget.game.opponentUsername}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: _buildContent(),
      ),
      actions: [
        if (_error != null)
          TextButton(onPressed: _loadPgn, child: const Text('Retry')),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 12),
            Text(
              'Failed to retrieve PGN:\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
      );
    }

    return Card(
      color: Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: SelectableText(
            _pgn ?? '',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}
