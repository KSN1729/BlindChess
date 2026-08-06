/// Model representing a user's Lichess profile and ratings.
class LichessProfile {
  final String username;
  final String? title;
  final int? blitzRating;
  final int? rapidRating;
  final int? gamesPlayed;
  final int? wins;
  final int? losses;
  final int? draws;
  final bool isOnline;

  const LichessProfile({
    required this.username,
    this.title,
    this.blitzRating,
    this.rapidRating,
    this.gamesPlayed,
    this.wins,
    this.losses,
    this.draws,
    this.isOnline = false,
  });

  /// Maps Lichess account details from API JSON parameters.
  factory LichessProfile.fromJson(Map<String, dynamic> json) {
    final user = json['username'] as String? ?? '';
    final title = json['title'] as String?;
    final blitz = json['perfs']?['blitz']?['rating'] as int?;
    final rapid = json['perfs']?['rapid']?['rating'] as int?;

    // Extract count details (wins, draws, losses, games) if present
    final count = json['count'] as Map<String, dynamic>?;
    final games = count?['all'] as int?;
    final wins = count?['win'] as int?;
    final losses = count?['loss'] as int?;
    final draws = count?['draw'] as int?;

    final isOnline = json['online'] as bool? ?? false;

    return LichessProfile(
      username: user,
      title: title,
      blitzRating: blitz,
      rapidRating: rapid,
      gamesPlayed: games,
      wins: wins,
      losses: losses,
      draws: draws,
      isOnline: isOnline,
    );
  }

  /// Converts this profile into a JSON-compatible map for persistence.
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'title': title,
      'perfs': {
        'blitz': {'rating': blitzRating},
        'rapid': {'rating': rapidRating},
      },
      'count': {
        'all': gamesPlayed,
        'win': wins,
        'loss': losses,
        'draw': draws,
      },
      'online': isOnline,
    };
  }
}
