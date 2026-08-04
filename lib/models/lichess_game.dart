/// Model representing a user's recent chess game played on Lichess.
class LichessGame {
  final String id;
  final String opponentUsername;
  final String colorPlayed;
  final String result;
  final DateTime date;

  /// Holds the lazy-loaded PGN string for this game once requested.
  String? pgn;

  LichessGame({
    required this.id,
    required this.opponentUsername,
    required this.colorPlayed,
    required this.result,
    required this.date,
    this.pgn,
  });

  /// Factory constructor to map Lichess game JSON properties.
  factory LichessGame.fromJson(
    Map<String, dynamic> json,
    String currentUsername,
  ) {
    final id = json['id'] as String? ?? 'unknown';

    // Parse creation timestamp (Unix milliseconds)
    final createdAt = json['createdAt'] as int?;
    final date = createdAt != null
        ? DateTime.fromMillisecondsSinceEpoch(createdAt)
        : DateTime.now();

    final players = json['players'] as Map<String, dynamic>? ?? const {};

    // Check if the current user played white or black
    final whiteUser = players['white']?['user']?['name'] as String?;
    final blackUser = players['black']?['user']?['name'] as String?;
    final blackUserId = players['black']?['user']?['id'] as String?;
    final isBlack =
        (blackUser != null &&
            blackUser.toLowerCase() == currentUsername.toLowerCase()) ||
        (blackUserId != null &&
            blackUserId.toLowerCase() == currentUsername.toLowerCase());

    // Resolve active color
    final colorPlayed = isBlack ? 'Black' : 'White';

    // Determine opponent username (handling Stockfish level for bots and deleted/unknown accounts)
    String opponent = 'Unknown';
    if (colorPlayed == 'White') {
      final blackMap = players['black'] as Map<String, dynamic>?;
      if (blackMap != null) {
        opponent =
            blackUser ??
            (blackMap['aiLevel'] != null
                ? 'Stockfish Level ${blackMap['aiLevel']}'
                : 'Unknown');
      }
    } else {
      final whiteMap = players['white'] as Map<String, dynamic>?;
      if (whiteMap != null) {
        opponent =
            whiteUser ??
            (whiteMap['aiLevel'] != null
                ? 'Stockfish Level ${whiteMap['aiLevel']}'
                : 'Unknown');
      }
    }

    // Determine the result from the current user's perspective
    final winner = json['winner'] as String?;
    String result = 'Draw';
    if (winner != null) {
      if (winner == 'white') {
        result = colorPlayed == 'White' ? 'Win' : 'Loss';
      } else if (winner == 'black') {
        result = colorPlayed == 'Black' ? 'Win' : 'Loss';
      }
    }

    // If PGN is already available inline (for alternative queries)
    final pgn = json['pgn'] as String?;

    return LichessGame(
      id: id,
      opponentUsername: opponent,
      colorPlayed: colorPlayed,
      result: result,
      date: date,
      pgn: pgn,
    );
  }
}
