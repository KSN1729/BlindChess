class LichessPlayer {
  final String id;
  final String name;
  final int? rating;
  final String? title;

  LichessPlayer({
    required this.id,
    required this.name,
    this.rating,
    this.title,
  });

  factory LichessPlayer.fromJson(Map<String, dynamic> json) {
    return LichessPlayer(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['username'] as String? ?? 'Anonymous',
      rating: json['rating'] as int?,
      title: json['title'] as String?,
    );
  }
}

class LichessClock {
  final int initial;
  final int increment;

  LichessClock({
    required this.initial,
    required this.increment,
  });

  factory LichessClock.fromJson(Map<String, dynamic> json) {
    return LichessClock(
      initial: json['initial'] as int? ?? 0,
      increment: json['increment'] as int? ?? 0,
    );
  }
}

class LichessChallenge {
  final String id;
  final String? url;
  final String status;
  final String challengerName;
  final int? challengerRating;
  final String? destUserName;
  final int? destUserRating;
  final String variant;
  final bool rated;
  final String speed;
  final int clockLimit;
  final int clockIncrement;
  final String color;

  LichessChallenge({
    required this.id,
    this.url,
    required this.status,
    required this.challengerName,
    this.challengerRating,
    this.destUserName,
    this.destUserRating,
    required this.variant,
    required this.rated,
    required this.speed,
    required this.clockLimit,
    required this.clockIncrement,
    required this.color,
  });

  factory LichessChallenge.fromJson(Map<String, dynamic> json) {
    final challenger = json['challenger'] ?? {};
    final destUser = json['destUser'];
    final timeControl = json['timeControl'] ?? {};
    final variant = json['variant'] ?? {};

    return LichessChallenge(
      id: json['id'] as String,
      url: json['url'] as String?,
      status: json['status'] as String? ?? 'created',
      challengerName: challenger['name'] as String? ?? challenger['id'] as String? ?? 'Anonymous',
      challengerRating: challenger['rating'] as int?,
      destUserName: destUser != null ? (destUser['name'] as String? ?? destUser['id'] as String?) : null,
      destUserRating: destUser != null ? (destUser['rating'] as int?) : null,
      variant: variant['key'] as String? ?? 'standard',
      rated: json['rated'] as bool? ?? false,
      speed: json['speed'] as String? ?? 'blitz',
      clockLimit: timeControl['limit'] as int? ?? 0,
      clockIncrement: timeControl['increment'] as int? ?? 0,
      color: json['color'] as String? ?? 'random',
    );
  }
}

class LichessActiveGame {
  final String gameId;
  final String fullId;
  final String color;
  final String fen;
  final bool hasMoved;
  final bool isMyTurn;
  final String? lastMove;
  final String opponentName;
  final int? opponentRating;
  final int secondsLeft;
  final String source;
  final String speed;
  final String variant;

  LichessActiveGame({
    required this.gameId,
    required this.fullId,
    required this.color,
    required this.fen,
    required this.hasMoved,
    required this.isMyTurn,
    this.lastMove,
    required this.opponentName,
    this.opponentRating,
    required this.secondsLeft,
    required this.source,
    required this.speed,
    required this.variant,
  });

  factory LichessActiveGame.fromJson(Map<String, dynamic> json) {
    final opponent = json['opponent'] ?? {};
    final variant = json['variant'] ?? {};

    return LichessActiveGame(
      gameId: json['gameId'] as String,
      fullId: json['fullId'] as String,
      color: json['color'] as String,
      fen: json['fen'] as String,
      hasMoved: json['hasMoved'] as bool? ?? false,
      isMyTurn: json['isMyTurn'] as bool? ?? false,
      lastMove: json['lastMove'] as String?,
      opponentName: opponent['username'] as String? ?? 'AI',
      opponentRating: opponent['rating'] as int?,
      secondsLeft: json['secondsLeft'] as int? ?? 0,
      source: json['source'] as String? ?? 'api',
      speed: json['speed'] as String? ?? 'blitz',
      variant: variant['key'] as String? ?? 'standard',
    );
  }
}

class LichessGameState {
  final String moves;
  final int wtime;
  final int btime;
  final int winc;
  final int binc;
  final String status;
  final String? winner;

  LichessGameState({
    required this.moves,
    required this.wtime,
    required this.btime,
    required this.winc,
    required this.binc,
    required this.status,
    this.winner,
  });

  factory LichessGameState.fromJson(Map<String, dynamic> json) {
    return LichessGameState(
      moves: json['moves'] as String? ?? '',
      wtime: json['wtime'] as int? ?? 0,
      btime: json['btime'] as int? ?? 0,
      winc: json['winc'] as int? ?? 0,
      binc: json['binc'] as int? ?? 0,
      status: json['status'] as String? ?? 'started',
      winner: json['winner'] as String?,
    );
  }
}

class LichessStreamMessage {
  final String type;
  final LichessGameState? state;
  final LichessPlayer? white;
  final LichessPlayer? black;
  final LichessClock? clock;

  LichessStreamMessage({
    required this.type,
    this.state,
    this.white,
    this.black,
    this.clock,
  });

  factory LichessStreamMessage.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'gameState';
    LichessGameState? state;
    LichessPlayer? white;
    LichessPlayer? black;
    LichessClock? clock;

    if (type == 'gameFull') {
      final stateJson = json['state'] ?? {};
      state = LichessGameState.fromJson(stateJson);
      if (json['white'] != null) {
        white = LichessPlayer.fromJson(json['white']);
      }
      if (json['black'] != null) {
        black = LichessPlayer.fromJson(json['black']);
      }
      if (json['clock'] != null) {
        clock = LichessClock.fromJson(json['clock']);
      }
    } else if (type == 'gameState') {
      state = LichessGameState.fromJson(json);
    }

    return LichessStreamMessage(
      type: type,
      state: state,
      white: white,
      black: black,
      clock: clock,
    );
  }
}

class LichessEvent {
  final String type;
  final LichessChallenge? challenge;
  final String? gameId;

  LichessEvent({
    required this.type,
    this.challenge,
    this.gameId,
  });

  factory LichessEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    LichessChallenge? challenge;
    String? gameId;

    if (type == 'challenge' || type == 'challengeCanceled' || type == 'challengeDeclined') {
      final chalJson = json['challenge'];
      if (chalJson != null) {
        challenge = LichessChallenge.fromJson(chalJson);
      }
    } else if (type == 'gameStart' || type == 'gameFinish') {
      final gameJson = json['game'] ?? {};
      gameId = gameJson['id'] as String?;
    }

    return LichessEvent(
      type: type,
      challenge: challenge,
      gameId: gameId,
    );
  }
}
