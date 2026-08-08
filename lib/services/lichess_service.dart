import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lichess_game.dart';
import '../models/lichess_connection_state.dart';
import 'lichess_api_client.dart';
import 'lichess_auth_service.dart';
import 'lichess_session_manager.dart';
import '../repositories/lichess_user_repository.dart';
import '../models/lichess_online_models.dart';

/// Facade service serving as the top-level Lichess integration interface.
/// Decouples authentication, storage, API, and repositories while preserving backward compatibility.
class LichessService with WidgetsBindingObserver {
  static final LichessService instance = LichessService._internal();

  /// Internal initializer for Singleton.
  LichessService._internal() {
    // Inject dependencies
    sessionManager = LichessSessionManager();
    apiClient = LichessApiClient(
      tokenProvider: () => sessionManager.accessToken,
      clientFactory: () => clientFactory(),
    );
    authService = LichessAuthService(
      onTokenExchanged: (token) async {
        await sessionManager.saveSession(token);
        await loadProfile();
      },
      onError: (err) {
        sessionManager.setConnectionState(LichessConnectionState.authenticationFailed);
        errorMessageNotifier.value = err;
      },
      onAuthStarted: () {
        sessionManager.setConnectionState(LichessConnectionState.connecting);
        errorMessageNotifier.value = null;
      },
      isAuthenticating: () => isAuthenticatingNotifier.value,
      clientFactory: () => clientFactory(),
    );
    userRepository = LichessUserRepository(apiClient: apiClient);

    _setupSynchronization();
  }

  // Storage keys for non-secret cached profile data
  static const String _keyUsername = 'lichess_username';
  static const String _keyBlitzRating = 'lichess_blitz_rating';
  static const String _keyRapidRating = 'lichess_rapid_rating';
  static const String _keyGamesPlayed = 'lichess_games_played';
  static const String _keyWins = 'lichess_wins';
  static const String _keyLosses = 'lichess_losses';
  static const String _keyDraws = 'lichess_draws';

  // Sub-services (Exposed for dependency injection in testing)
  late final LichessSessionManager sessionManager;
  late final LichessApiClient apiClient;
  late final LichessAuthService authService;
  late final LichessUserRepository userRepository;

  // Notifiers mapped to sub-services for backward compatibility with UI
  final ValueNotifier<bool> isAuthenticatedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> usernameNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<int?> blitzRatingNotifier = ValueNotifier<int?>(null);
  final ValueNotifier<int?> rapidRatingNotifier = ValueNotifier<int?>(null);
  final ValueNotifier<bool> isAuthenticatingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> errorMessageNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<int?> gamesPlayedNotifier = ValueNotifier<int?>(null);
  final ValueNotifier<int?> winsNotifier = ValueNotifier<int?>(null);
  final ValueNotifier<int?> lossesNotifier = ValueNotifier<int?>(null);
  final ValueNotifier<int?> drawsNotifier = ValueNotifier<int?>(null);

  /// Factory function to create HttpClients, overridable in testing.
  HttpClient Function() clientFactory = () => HttpClient();

  /// Gets the currently stored Lichess access token.
  String? get accessToken => sessionManager.accessToken;

  /// Exposes current authentication status.
  bool get isAuthenticated => isAuthenticatedNotifier.value;

  /// Exposes authenticated username.
  String? get username => usernameNotifier.value;

  /// Exposes current Blitz rating.
  int? get blitzRating => blitzRatingNotifier.value;

  /// Exposes current Rapid rating.
  int? get rapidRating => rapidRatingNotifier.value;

  /// Exposes current total games played.
  int? get gamesPlayed => gamesPlayedNotifier.value;

  /// Exposes current win count.
  int? get wins => winsNotifier.value;

  /// Exposes current loss count.
  int? get losses => lossesNotifier.value;

  /// Exposes current draw count.
  int? get draws => drawsNotifier.value;

  /// Setup reactive listeners between modular services and UI facade notifiers.
  void _setupSynchronization() {
    sessionManager.connectionStateNotifier.addListener(() {
      final state = sessionManager.connectionState;
      isAuthenticatedNotifier.value = (state == LichessConnectionState.connected);
      if (state == LichessConnectionState.connecting) {
        isAuthenticatingNotifier.value = true;
      } else {
        isAuthenticatingNotifier.value = false;
      }
    });

    userRepository.profileNotifier.addListener(() {
      final profile = userRepository.profile;
      usernameNotifier.value = profile?.username;
      blitzRatingNotifier.value = profile?.blitzRating;
      rapidRatingNotifier.value = profile?.rapidRating;
      gamesPlayedNotifier.value = profile?.gamesPlayed;
      winsNotifier.value = profile?.wins;
      lossesNotifier.value = profile?.losses;
      drawsNotifier.value = profile?.draws;
    });
  }

  /// Initializes the service, restoring the secure session and listening to redirects.
  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);

    // Initial non-secret profile cache restore
    final prefs = await SharedPreferences.getInstance();
    usernameNotifier.value = prefs.getString(_keyUsername);
    final blitz = prefs.getInt(_keyBlitzRating);
    blitzRatingNotifier.value = blitz == -1 ? null : blitz;
    final rapid = prefs.getInt(_keyRapidRating);
    rapidRatingNotifier.value = rapid == -1 ? null : rapid;
    final games = prefs.getInt(_keyGamesPlayed);
    gamesPlayedNotifier.value = games == -1 || games == null ? null : games;
    final winsVal = prefs.getInt(_keyWins);
    winsNotifier.value = winsVal == -1 || winsVal == null ? null : winsVal;
    final lossesVal = prefs.getInt(_keyLosses);
    lossesNotifier.value = lossesVal == -1 || lossesVal == null ? null : lossesVal;
    final drawsVal = prefs.getInt(_keyDraws);
    drawsNotifier.value = drawsVal == -1 || drawsVal == null ? null : drawsVal;

    // Restore encrypted token session
    final oldToken = prefs.getString('lichess_access_token');
    if (oldToken != null && oldToken.isNotEmpty) {
      await sessionManager.saveSession(oldToken);
      await prefs.remove('lichess_access_token');
    }

    final restored = await sessionManager.restoreSession();
    if (restored && !Platform.environment.containsKey('FLUTTER_TEST')) {
      // Async background profile refresh on next event loop tick to let tests register mocks
      Future.delayed(Duration.zero, () {
        loadProfile().catchError((e) {
          debugPrint('Error loading initial Lichess profile: $e');
        });
      });
    }

    // Skip deep link callbacks during widget testing
    final isTesting = WidgetsBinding.instance.toString().contains('TestWidgetsFlutterBinding');
    if (isTesting) return;

    authService.initRedirectListener();
  }

  /// App lifecycle listener to detect when user resumes the app from the browser.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User switched back from the browser. Give 1.5s for app_links callback.
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (isAuthenticatingNotifier.value && !isAuthenticated) {
          sessionManager.setConnectionState(LichessConnectionState.authenticationFailed);
          if (errorMessageNotifier.value == null) {
            errorMessageNotifier.value = 'Login was interrupted or cancelled.';
          }
        }
      });
    }
  }

  /// Launches system browser OAuth PKCE sequence.
  Future<void> login() async {
    await authService.login();
  }

  /// Clears session tokens, profile caches, and notifiers.
  Future<void> logout() async {
    await sessionManager.clearSession();
    userRepository.clearProfile();

    usernameNotifier.value = null;
    blitzRatingNotifier.value = null;
    rapidRatingNotifier.value = null;
    gamesPlayedNotifier.value = null;
    winsNotifier.value = null;
    lossesNotifier.value = null;
    drawsNotifier.value = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyBlitzRating);
    await prefs.remove(_keyRapidRating);
    await prefs.remove(_keyGamesPlayed);
    await prefs.remove(_keyWins);
    await prefs.remove(_keyLosses);
    await prefs.remove(_keyDraws);
  }

  /// Resets underlying service queues for testing.
  void resetForTesting() {
    apiClient.resetQueue();
    authService.dispose();
  }

  /// Centralized wrapper for API requests that tracks network availability state.
  Future<T> _runWithNetworkCheck<T>(Future<T> Function() action) async {
    try {
      final result = await action();
      if (sessionManager.connectionState == LichessConnectionState.networkUnavailable) {
        sessionManager.setConnectionState(LichessConnectionState.connected);
      }
      return result;
    } on LichessNetworkException {
      sessionManager.setConnectionState(LichessConnectionState.networkUnavailable);
      rethrow;
    }
  }

  /// Formats any error/exception into a clean, user-friendly string.
  static String formatError(dynamic err) {
    if (err is LichessApiException) {
      return err.userFriendlyMessage;
    }
    if (err is LichessNetworkException) {
      return 'Network connection failed.';
    }
    if (err is LichessUnauthorizedException) {
      return 'Session expired. Please log in again.';
    }
    if (err is LichessRateLimitException) {
      return 'Rate limit exceeded. Please try again later.';
    }
    final str = err.toString();
    if (str.startsWith('Exception: ')) {
      return str.substring(11);
    }
    return str;
  }

  /// Exchanges redirect callback credentials.
  Future<void> handleIncomingUri(Uri uri) async {
    await authService.handleIncomingUri(uri);
  }

  /// Loads account profile statistics.
  Future<void> loadProfile() async {
    if (accessToken == null) return;
    try {
      final profile = await _runWithNetworkCheck(() => userRepository.loadProfile());

      // Persist public details in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUsername, profile.username);
      await prefs.setInt(_keyBlitzRating, profile.blitzRating ?? -1);
      await prefs.setInt(_keyRapidRating, profile.rapidRating ?? -1);
      await prefs.setInt(_keyGamesPlayed, profile.gamesPlayed ?? -1);
      await prefs.setInt(_keyWins, profile.wins ?? -1);
      await prefs.setInt(_keyLosses, profile.losses ?? -1);
      await prefs.setInt(_keyDraws, profile.draws ?? -1);
    } catch (e) {
      if (e is LichessUnauthorizedException) {
        debugPrint('Unauthorized Lichess token. Logging out.');
        await logout();
      } else if (e is LichessNetworkException) {
        sessionManager.setConnectionState(LichessConnectionState.networkUnavailable);
      } else {
        debugPrint('Error loading Lichess profile stats: $e');
      }
      rethrow;
    }
  }

  /// Streams and fetches the user's recent games.
  Future<List<LichessGame>> fetchRecentGames({int max = 15}) async {
    final user = username;
    if (user == null || accessToken == null) {
      throw Exception('Not authenticated with Lichess.');
    }

    final responseBody = await _runWithNetworkCheck(
      () => apiClient.stream('/api/games/user/$user?max=$max'),
    );
    final List<LichessGame> games = [];
    await for (final line in responseBody) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final gameJson = json.decode(trimmed);
        games.add(LichessGame.fromJson(gameJson, user));
      } catch (e) {
        debugPrint('Error parsing streamed game: $e');
      }
    }
    return games;
  }

  /// Fetches game PGN.
  Future<String> fetchGamePgn(String gameId) async {
    if (accessToken == null) {
      throw Exception('Not authenticated with Lichess.');
    }
    return _runWithNetworkCheck(() => apiClient.getString(
      '/game/export/$gameId.pgn',
      headers: {'Accept': 'application/x-chess-pgn'},
    ));
  }

  /// Creates a challenge against the Lichess AI.
  /// Returns the gameId on success, or throws an exception on failure.
  Future<String> challengeAi({
    required int level,
    required int clockLimit,
    required int clockIncrement,
    required String color,
  }) async {
    if (accessToken == null) {
      throw Exception('Not authenticated with Lichess.');
    }

    final response = await _runWithNetworkCheck(() => apiClient.post(
      '/api/challenge/ai',
      body: 'level=$level'
          '&clock.limit=$clockLimit'
          '&clock.increment=$clockIncrement'
          '&color=$color'
          '&variant=standard',
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    ));

    final gameId = response['id'] as String?;
    if (gameId != null && gameId.isNotEmpty) {
      return gameId;
    }
    throw Exception('Lichess response did not contain a valid game ID.');
  }

  /// Transmits a legal move (in UCI format) to the Lichess board API.
  Future<void> sendMove(String gameId, String move) async {
    if (accessToken == null) {
      throw Exception('Not authenticated with Lichess.');
    }
    await _runWithNetworkCheck(() => apiClient.post('/api/board/game/$gameId/move/$move'));
  }

  /// Forfeits the game, resulting in a loss.
  Future<void> resignGame(String gameId) async {
    if (accessToken == null) {
      throw Exception('Not authenticated with Lichess.');
    }
    await _runWithNetworkCheck(() => apiClient.post('/api/board/game/$gameId/resign'));
  }

  /// Requests a takeback (undo) on Lichess.
  Future<void> requestTakeback(String gameId) async {
    if (accessToken == null) {
      throw Exception('Not authenticated with Lichess.');
    }
    await _runWithNetworkCheck(() => apiClient.post('/api/board/game/$gameId/takeback/yes'));
  }

  /// Ends the game without a result, only valid before both players make their first move.
  Future<void> abortGame(String gameId) async {
    if (accessToken == null) {
      throw Exception('Not authenticated with Lichess.');
    }
    await _runWithNetworkCheck(() => apiClient.post('/api/board/game/$gameId/abort'));
  }

  /// Offers or accepts a draw (accept = true -> /draw/yes, accept = false -> /draw/no).
  Future<void> drawGame(String gameId, bool accept) async {
    if (accessToken == null) {
      throw Exception('Not authenticated with Lichess.');
    }
    final acceptPath = accept ? 'yes' : 'no';
    await _runWithNetworkCheck(() => apiClient.post('/api/board/game/$gameId/draw/$acceptPath'));
  }

  /// Opens a long-lived connection to stream board game events (NDJSON).
  /// Returns a stream of events as decoded JSON maps.
  Stream<Map<String, dynamic>> streamGameState(String gameId) {
    if (accessToken == null) {
      throw Exception('Not authenticated with Lichess.');
    }

    final controller = StreamController<Map<String, dynamic>>();
    StreamSubscription? subscription;
    bool isCancelled = false;

    controller.onCancel = () {
      isCancelled = true;
      subscription?.cancel();
    };

    controller.onListen = () async {
      try {
        final lineStream = await apiClient.stream('/api/board/game/stream/$gameId');
        if (isCancelled) {
          return;
        }
        subscription = lineStream.listen(
          (line) {
            if (isCancelled) return;
            final trimmed = line.trim();
            if (trimmed.isEmpty) return; // Skip keep-alive newlines
            try {
              final data = json.decode(trimmed);
              if (data is Map<String, dynamic> && !controller.isClosed) {
                controller.add(data);
              }
            } catch (e) {
              debugPrint('Failed to parse streamed game NDJSON line: $e');
            }
          },
          onError: (error) {
            if (!controller.isClosed) {
              controller.addError(error);
              controller.close();
            }
          },
          onDone: () {
            if (!controller.isClosed) {
              controller.close();
            }
          },
          cancelOnError: true,
        );

        if (isCancelled) {
          subscription?.cancel();
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
          controller.close();
        }
      }
    };

    return controller.stream;
  }

  /// Creates an open challenge on Lichess.
  Future<LichessChallenge> createOpenChallenge({
    required int clockLimit,
    required int clockIncrement,
    required String color,
    required bool rated,
  }) async {
    if (accessToken == null) {
      throw Exception('Not authenticated with Lichess.');
    }
    
    final response = await _runWithNetworkCheck(() => apiClient.post(
      '/api/challenge/open',
      body: 'clock.limit=$clockLimit'
          '&clock.increment=$clockIncrement'
          '&color=$color'
          '&rated=${rated.toString()}'
          '&variant=standard',
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    ));
    
    final challengeJson = response['challenge'];
    if (challengeJson != null) {
      return LichessChallenge.fromJson(challengeJson);
    }
    throw Exception('Lichess response did not contain a valid challenge.');
  }

  /// Creates a challenge against a specific opponent.
  Future<LichessChallenge> createOpponentChallenge({
    required String opponent,
    required int clockLimit,
    required int clockIncrement,
    required String color,
    required bool rated,
  }) async {
    if (accessToken == null) {
      throw Exception('Not authenticated with Lichess.');
    }
    
    final response = await _runWithNetworkCheck(() => apiClient.post(
      '/api/challenge/$opponent',
      body: 'clock.limit=$clockLimit'
          '&clock.increment=$clockIncrement'
          '&color=$color'
          '&rated=${rated.toString()}'
          '&variant=standard',
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    ));
    
    final challengeJson = response['challenge'];
    if (challengeJson != null) {
      return LichessChallenge.fromJson(challengeJson);
    }
    throw Exception('Lichess response did not contain a valid challenge.');
  }

  /// Fetches incoming and outgoing challenges.
  Future<Map<String, List<LichessChallenge>>> fetchChallenges() async {
    if (accessToken == null) {
      throw Exception('Not authenticated with Lichess.');
    }

    final response = await _runWithNetworkCheck(() => apiClient.get('/api/challenge'));
    final incomingList = (response['in'] as List? ?? [])
        .map((item) => LichessChallenge.fromJson(item as Map<String, dynamic>))
        .toList();
    final outgoingList = (response['out'] as List? ?? [])
        .map((item) => LichessChallenge.fromJson(item as Map<String, dynamic>))
        .toList();

    return {
      'in': incomingList,
      'out': outgoingList,
    };
  }

  /// Accepts an incoming challenge.
  Future<void> acceptChallenge(String challengeId) async {
    if (accessToken == null) {
      throw Exception('Not authenticated with Lichess.');
    }
    await _runWithNetworkCheck(() => apiClient.post('/api/challenge/$challengeId/accept'));
  }

  /// Declines an incoming challenge.
  Future<void> declineChallenge(String challengeId, {String reason = 'generic'}) async {
    if (accessToken == null) {
      throw Exception('Not authenticated with Lichess.');
    }
    await _runWithNetworkCheck(() => apiClient.post(
      '/api/challenge/$challengeId/decline',
      body: 'reason=$reason',
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    ));
  }

  /// Cancels a pending outgoing challenge.
  Future<void> cancelChallenge(String challengeId) async {
    if (accessToken == null) {
      throw Exception('Not authenticated with Lichess.');
    }
    await _runWithNetworkCheck(() => apiClient.post('/api/challenge/$challengeId/cancel'));
  }

  /// Fetches the user's currently active games.
  Future<List<LichessActiveGame>> fetchActiveGames() async {
    if (accessToken == null) {
      throw Exception('Not authenticated with Lichess.');
    }
    
    final response = await _runWithNetworkCheck(() => apiClient.get('/api/account/playing'));
    final playing = response['nowPlaying'] as List? ?? [];
    return playing
        .map((item) => LichessActiveGame.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Streams events for the authenticated user, automatically handling keep-alive heartbeats and reconnect backoff.
  Stream<LichessEvent> streamEvents() {
    if (accessToken == null) {
      throw Exception('Not authenticated with Lichess.');
    }

    final controller = StreamController<LichessEvent>.broadcast();
    StreamSubscription? subscription;
    Timer? heartbeatTimer;
    bool isCancelled = false;
    int reconnectDelaySec = 1;

    void connect() async {
      if (isCancelled || controller.isClosed) return;

      try {
        if (sessionManager.connectionState == LichessConnectionState.networkUnavailable) {
          sessionManager.setConnectionState(LichessConnectionState.reconnecting);
        } else if (sessionManager.connectionState == LichessConnectionState.connected) {
          sessionManager.setConnectionState(LichessConnectionState.reconnecting);
        }

        final lineStream = await apiClient.stream('/api/stream/event');
        if (isCancelled || controller.isClosed) return;

        sessionManager.setConnectionState(LichessConnectionState.connected);
        reconnectDelaySec = 1;

        void resetHeartbeat() {
          heartbeatTimer?.cancel();
          heartbeatTimer = Timer(const Duration(seconds: 25), () {
            debugPrint('Lichess event stream heartbeat timeout. Reconnecting...');
            subscription?.cancel();
            heartbeatTimer?.cancel();
            connect();
          });
        }

        resetHeartbeat();

        subscription = lineStream.listen(
          (line) {
            resetHeartbeat();
            final trimmed = line.trim();
            if (trimmed.isEmpty) return;
            try {
              final data = json.decode(trimmed);
              if (data is Map<String, dynamic>) {
                final event = LichessEvent.fromJson(data);
                if (!controller.isClosed) {
                  controller.add(event);
                }
              }
            } catch (e) {
              debugPrint('Failed to parse streamed event: $e');
            }
          },
          onError: (error) {
            debugPrint('Lichess event stream error: $error. Reconnecting...');
            heartbeatTimer?.cancel();
            subscription?.cancel();
            
            if (error is LichessUnauthorizedException) {
              sessionManager.setConnectionState(LichessConnectionState.authenticationExpired);
              if (!controller.isClosed) {
                controller.addError(error);
                scheduleMicrotask(() {
                  if (!controller.isClosed) {
                    controller.close();
                  }
                });
              }
              return;
            }

            if (error is LichessNetworkException) {
              sessionManager.setConnectionState(LichessConnectionState.networkUnavailable);
            }

            Future.delayed(Duration(seconds: reconnectDelaySec), () {
              reconnectDelaySec = (reconnectDelaySec * 2).clamp(1, 60);
              connect();
            });
          },
          onDone: () {
            debugPrint('Lichess event stream completed. Reconnecting...');
            heartbeatTimer?.cancel();
            subscription?.cancel();

            Future.delayed(Duration(seconds: reconnectDelaySec), () {
              reconnectDelaySec = (reconnectDelaySec * 2).clamp(1, 60);
              connect();
            });
          },
          cancelOnError: true,
        );
      } catch (e) {
        debugPrint('Failed to establish Lichess event stream: $e. Reconnecting...');
        
        if (e is LichessUnauthorizedException) {
          sessionManager.setConnectionState(LichessConnectionState.authenticationExpired);
          if (!controller.isClosed) {
            controller.addError(e);
            scheduleMicrotask(() {
              if (!controller.isClosed) {
                controller.close();
              }
            });
          }
          return;
        }

        if (e is LichessNetworkException) {
          sessionManager.setConnectionState(LichessConnectionState.networkUnavailable);
        }

        Future.delayed(Duration(seconds: reconnectDelaySec), () {
          reconnectDelaySec = (reconnectDelaySec * 2).clamp(1, 60);
          connect();
        });
      }
    }

    controller.onListen = () {
      isCancelled = false;
      connect();
    };

    controller.onCancel = () {
      isCancelled = true;
      heartbeatTimer?.cancel();
      subscription?.cancel();
    };

    return controller.stream;
  }
}
