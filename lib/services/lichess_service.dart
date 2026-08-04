import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lichess_game.dart';

/// Service in charge of Lichess OAuth2 Authentication and profile management.
///
/// [Reverse Domain Notation Scheme]
/// Lichess requires custom URI schemes to follow reverse domain notation (e.g. `org.blindchess.app`)
/// rather than simple names (like `blindchess`). This mitigates "scheme collision hijackings"
/// where multiple apps register the same simple scheme on a device, leading to ambiguous routing.
///
/// [Browser-Based Async Redirect Safety]
/// Authentication relying on external system browsers is inherently fragile. The user might close the
/// browser, cancel authorization, or background the app indefinitely. We implement:
/// 1. A 2-minute timeout timer to automatically release the spinner if no redirect is received.
/// 2. An App Lifecycle Observer (resumed state detection) to recover and clear loading flags if the
///    user returns to the app from the browser without authenticating.
/// 3. Standard query parameter error handlers to capture rejected permissions.
class LichessService with WidgetsBindingObserver {
  static final LichessService instance = LichessService._internal();
  LichessService._internal();

  static const String _keyToken = 'lichess_access_token';
  static const String _keyUsername = 'lichess_username';
  static const String _keyBlitzRating = 'lichess_blitz_rating';
  static const String _keyRapidRating = 'lichess_rapid_rating';
  static const String _keyState = 'lichess_oauth_state';
  static const String _keyVerifier = 'lichess_oauth_verifier';
  static const String _keyGamesPlayed = 'lichess_games_played';
  static const String _keyWins = 'lichess_wins';
  static const String _keyLosses = 'lichess_losses';
  static const String _keyDraws = 'lichess_draws';

  final ValueNotifier<bool> isAuthenticatedNotifier = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<String?> usernameNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<int?> blitzRatingNotifier = ValueNotifier<int?>(null);
  final ValueNotifier<int?> rapidRatingNotifier = ValueNotifier<int?>(null);
  final ValueNotifier<bool> isAuthenticatingNotifier = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<String?> errorMessageNotifier = ValueNotifier<String?>(
    null,
  );
  final ValueNotifier<int?> gamesPlayedNotifier = ValueNotifier<int?>(null);
  final ValueNotifier<int?> winsNotifier = ValueNotifier<int?>(null);
  final ValueNotifier<int?> lossesNotifier = ValueNotifier<int?>(null);
  final ValueNotifier<int?> drawsNotifier = ValueNotifier<int?>(null);

  String? _accessToken;
  final AppLinks _appLinks = AppLinks();
  Timer? _authTimer;

  /// Factory function to create HttpClients, overridable in testing.
  HttpClient Function() clientFactory = () => HttpClient();

  /// Gets the currently stored Lichess access token.
  String? get accessToken => _accessToken;

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

  /// Initializes the service, loading cached credentials and listening to deep link redirects.
  Future<void> init() async {
    // Add lifecycle observer to listen to browser exits
    WidgetsBinding.instance.addObserver(this);

    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_keyToken);

    if (_accessToken != null) {
      isAuthenticatedNotifier.value = true;
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
      lossesNotifier.value = lossesVal == -1 || lossesVal == null
          ? null
          : lossesVal;
      final drawsVal = prefs.getInt(_keyDraws);
      drawsNotifier.value = drawsVal == -1 || drawsVal == null
          ? null
          : drawsVal;

      // Async background profile refresh
      loadProfile().catchError((e) {
        debugPrint('Error loading initial profile: $e');
      });
    }

    // Skip native deep link interception during tests to avoid MissingPluginException
    final isTesting = WidgetsBinding.instance.toString().contains(
      'TestWidgetsFlutterBinding',
    );
    if (isTesting) return;

    // Set up deep link stream listener
    _appLinks.uriLinkStream.listen(
      (uri) {
        handleIncomingUri(uri);
      },
      onError: (err) {
        debugPrint('Deep Link listener error: $err');
      },
    );

    // Check for initial deep link (if cold started via callback scheme)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        handleIncomingUri(initialUri);
      }
    } catch (e) {
      debugPrint('Failed to get initial app link: $e');
    }
  }

  /// App lifecycle listener to detect when user resumes the app from the browser.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User switched back to the application.
      // Wait 1.5 seconds to allow any pending deep-link callbacks to trigger first.
      // If still spinning and not authenticated, clean up state.
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (isAuthenticatingNotifier.value && !isAuthenticated) {
          _authTimer?.cancel();
          _authTimer = null;
          isAuthenticatingNotifier.value = false;
          if (errorMessageNotifier.value == null) {
            errorMessageNotifier.value = 'Login was interrupted or cancelled.';
          }
        }
      });
    }
  }

  /// Initiates the Lichess Login flow by launching the system browser with PKCE parameters.
  Future<void> login() async {
    _authTimer?.cancel();
    errorMessageNotifier.value = null;
    isAuthenticatingNotifier.value = true;

    final verifier = _generateCodeVerifier();
    final challenge = _generateCodeChallenge(verifier);
    final state = _generateState();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVerifier, verifier);
    await prefs.setString(_keyState, state);

    // Setup 2-minute safety timeout
    _authTimer = Timer(const Duration(minutes: 2), () {
      if (isAuthenticatingNotifier.value) {
        isAuthenticatingNotifier.value = false;
        errorMessageNotifier.value = 'Connection timed out. Please try again.';
      }
    });

    final authUrl = Uri.parse(
      'https://lichess.org/oauth'
      '?response_type=code'
      '&client_id=blindchess'
      '&redirect_uri=org.blindchess.app://oauth-callback'
      '&scope=board:play challenge:write challenge:read'
      '&code_challenge_method=S256'
      '&code_challenge=$challenge'
      '&state=$state',
    );

    try {
      await launchUrl(authUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch OAuth URL: $e');
      _authTimer?.cancel();
      _authTimer = null;
      isAuthenticatingNotifier.value = false;
      errorMessageNotifier.value = 'Failed to launch system browser.';
    }
  }

  /// Logs the user out, clearing cached states and preferences.
  Future<void> logout() async {
    _authTimer?.cancel();
    _authTimer = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyBlitzRating);
    await prefs.remove(_keyRapidRating);
    await prefs.remove(_keyState);
    await prefs.remove(_keyVerifier);
    await prefs.remove(_keyGamesPlayed);
    await prefs.remove(_keyWins);
    await prefs.remove(_keyLosses);
    await prefs.remove(_keyDraws);

    _accessToken = null;
    isAuthenticatedNotifier.value = false;
    usernameNotifier.value = null;
    blitzRatingNotifier.value = null;
    rapidRatingNotifier.value = null;
    isAuthenticatingNotifier.value = false;
    errorMessageNotifier.value = null;
    gamesPlayedNotifier.value = null;
    winsNotifier.value = null;
    lossesNotifier.value = null;
    drawsNotifier.value = null;
  }

  /// Handles custom URI redirects from Lichess authentication server.
  Future<void> handleIncomingUri(Uri uri) async {
    if (uri.scheme != 'org.blindchess.app' || uri.host != 'oauth-callback') {
      return;
    }

    if (isAuthenticatedNotifier.value) {
      debugPrint('Already authenticated, ignoring incoming URI.');
      return;
    }

    // Check for explicit error responses (e.g. user denied scope permission)
    final error = uri.queryParameters['error'];
    if (error != null) {
      _authTimer?.cancel();
      _authTimer = null;
      isAuthenticatingNotifier.value = false;
      if (error == 'access_denied') {
        errorMessageNotifier.value = 'Lichess authorization was declined.';
      } else {
        errorMessageNotifier.value = 'Lichess error: $error';
      }
      return;
    }

    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];

    if (code == null || state == null) {
      _authTimer?.cancel();
      _authTimer = null;
      isAuthenticatingNotifier.value = false;
      errorMessageNotifier.value = 'Malformed authorization response.';
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedState = prefs.getString(_keyState);
    final savedVerifier = prefs.getString(_keyVerifier);

    if (savedState == null || savedVerifier == null) {
      if (isAuthenticatingNotifier.value) {
        debugPrint('OAuth flow already in progress, ignoring duplicate URI.');
        return;
      }
      _authTimer?.cancel();
      _authTimer = null;
      isAuthenticatingNotifier.value = false;
      errorMessageNotifier.value = 'Security verification state mismatch.';
      return;
    }

    if (savedState != state) {
      debugPrint('State mismatch. Aborting OAuth flow.');
      _authTimer?.cancel();
      _authTimer = null;
      isAuthenticatingNotifier.value = false;
      errorMessageNotifier.value = 'Security verification state mismatch.';
      return;
    }

    // Clear state/verifier immediately
    await prefs.remove(_keyState);
    await prefs.remove(_keyVerifier);

    await _exchangeCodeForToken(code, savedVerifier);
  }

  /// Exchanges the authorization code for a Lichess API bearer access token.
  Future<void> _exchangeCodeForToken(String code, String codeVerifier) async {
    try {
      final client = clientFactory();
      final request = await client.postUrl(
        Uri.parse('https://lichess.org/api/token'),
      );

      request.headers.set(
        'User-Agent',
        'BlindChess/1.0.0 (contact: support@blindchess.org)',
      );
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
      );

      final body =
          'grant_type=authorization_code'
          '&code=$code'
          '&code_verifier=$codeVerifier'
          '&redirect_uri=org.blindchess.app://oauth-callback'
          '&client_id=blindchess';

      request.write(body);

      final response = await request.close();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = json.decode(responseBody);

        final token = data['access_token'] as String;
        _accessToken = token;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyToken, token);
        isAuthenticatedNotifier.value = true;

        await loadProfile();
      } else {
        debugPrint('Token exchange failed with status: ${response.statusCode}');
        _authTimer?.cancel();
        _authTimer = null;
        isAuthenticatingNotifier.value = false;
        errorMessageNotifier.value =
            'Lichess token exchange failed (HTTP ${response.statusCode}).';
      }
    } catch (e) {
      debugPrint('Error exchanging code for token: $e');
      _authTimer?.cancel();
      _authTimer = null;
      isAuthenticatingNotifier.value = false;
      errorMessageNotifier.value = 'Network error during token exchange.';
    }
  }

  /// Loads the player profile details from the Lichess API.
  Future<void> loadProfile() async {
    if (_accessToken == null) return;

    try {
      final client = clientFactory();
      final request = await client.getUrl(
        Uri.parse('https://lichess.org/api/account'),
      );

      request.headers.set(
        'User-Agent',
        'BlindChess/1.0.0 (contact: support@blindchess.org)',
      );
      request.headers.set('Authorization', 'Bearer $_accessToken');

      final response = await request.close();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = json.decode(responseBody);

        final user = data['username'] as String;
        final blitz = data['perfs']?['blitz']?['rating'] as int?;
        final rapid = data['perfs']?['rapid']?['rating'] as int?;

        final games = data['count']?['all'] as int?;
        final winsVal = data['count']?['win'] as int?;
        final lossesVal = data['count']?['loss'] as int?;
        final drawsVal = data['count']?['draw'] as int?;

        usernameNotifier.value = user;
        blitzRatingNotifier.value = blitz;
        rapidRatingNotifier.value = rapid;
        gamesPlayedNotifier.value = games;
        winsNotifier.value = winsVal;
        lossesNotifier.value = lossesVal;
        drawsNotifier.value = drawsVal;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyUsername, user);
        await prefs.setInt(_keyBlitzRating, blitz ?? -1);
        await prefs.setInt(_keyRapidRating, rapid ?? -1);
        await prefs.setInt(_keyGamesPlayed, games ?? -1);
        await prefs.setInt(_keyWins, winsVal ?? -1);
        await prefs.setInt(_keyLosses, lossesVal ?? -1);
        await prefs.setInt(_keyDraws, drawsVal ?? -1);

        // Success - release authentication timer
        _authTimer?.cancel();
        _authTimer = null;
        errorMessageNotifier.value = null;
      } else if (response.statusCode == 401) {
        debugPrint('Lichess access token invalid/unauthorized. Logging out.');
        await logout();
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      _authTimer?.cancel();
      _authTimer = null;
      // We don't log out here in case it is a temporary network glitch, but we cancel the auth timer
    } finally {
      isAuthenticatingNotifier.value = false;
    }
  }

  // --- PKCE Helpers ---

  /// Generates a cryptographically secure random verifier string.
  String _generateCodeVerifier() {
    final random = Random.secure();
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    return List.generate(
      80,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  /// Generates a SHA-256 based code challenge for PKCE matching.
  String _generateCodeChallenge(String verifier) {
    final bytes = ascii.encode(verifier);
    final digest = sha256.convert(bytes);
    // Base64url encode without padding as required by OAuth PKCE specs
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Generates a random state string to mitigate cross-site request forgery.
  String _generateState() {
    final random = Random();
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(
      16,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  // --- Recent Games and PGN Export API ---

  /// BEGINNER EXPLANATION: Newline Delimited JSON (NDJSON) & Streaming responses
  ///
  /// 1. What is NDJSON?
  ///    NDJSON stands for Newline Delimited JSON. Instead of returning a standard JSON array
  ///    which wraps items inside brackets `[...]` separated by commas, NDJSON returns a stream
  ///    of separate, independent JSON objects, each separated by a newline character `\n`.
  ///
  /// 2. Why does Lichess use NDJSON?
  ///    When exporting large sets of chess games, a standard JSON array requires the server
  ///    to hold all games in memory to construct the final array, and requires the client
  ///    to load the entire file into memory before parsing.
  ///    By streaming NDJSON, the server can write and send each game individually as soon as
  ///    it reads it from the database, and the client can parse each line incrementally without
  ///    buffering the entire response body at once. This results in minimal memory usage.
  ///
  /// 3. Why are game PGNs loaded lazily (on-demand)?
  ///    PGN strings contain the full chess notation, headers, and metadata, which can be
  ///    extremely large. Fetching PGNs for 15 games eagerly would require transferring and
  ///    parsing a heavy body over the network on initial screen load.
  ///    By lazily fetching the PGN only when the user taps on a specific game, we conserve
  ///    network bandwidth, reduce processing overhead, and protect our client from triggering
  ///    Lichess API rate-limiting blocks.

  /// Streams and fetches the user's recent games from Lichess using the NDJSON endpoint.
  Future<List<LichessGame>> fetchRecentGames({int max = 15}) async {
    final user = username;
    if (user == null || _accessToken == null) {
      throw Exception('Not authenticated with Lichess.');
    }

    final client = clientFactory();
    final uri = Uri.parse('https://lichess.org/api/games/user/$user?max=$max');
    final request = await client.getUrl(uri);
    request.headers.set(
      'User-Agent',
      'BlindChess/1.0.0 (contact: support@blindchess.org)',
    );
    request.headers.set('Authorization', 'Bearer $_accessToken');
    request.headers.set('Accept', 'application/x-ndjson');

    final response = await request.close();
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final responseBody = await response.transform(utf8.decoder).join();
      final List<LichessGame> games = [];
      // Split by newline delimiter as specified by the NDJSON protocol
      final lines = responseBody.split(RegExp(r'\r?\n'));
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        try {
          final gameJson = json.decode(trimmed);
          games.add(LichessGame.fromJson(gameJson, user));
        } catch (e) {
          debugPrint('Error parsing game JSON line: $e');
        }
      }
      return games;
    } else {
      throw Exception(
        'Failed to fetch recent games (HTTP ${response.statusCode})',
      );
    }
  }

  Future<String> fetchGamePgn(String gameId) async {
    if (_accessToken == null) {
      throw Exception('Not authenticated with Lichess.');
    }

    final client = clientFactory();
    final uri = Uri.parse('https://lichess.org/game/export/$gameId.pgn');
    final request = await client.getUrl(uri);
    request.headers.set(
      'User-Agent',
      'BlindChess/1.0.0 (contact: support@blindchess.org)',
    );
    request.headers.set('Authorization', 'Bearer $_accessToken');
    request.headers.set('Accept', 'application/x-chess-pgn');

    final response = await request.close();
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final pgn = await response.transform(utf8.decoder).join();
      return pgn;
    } else {
      throw Exception('Failed to fetch PGN (HTTP ${response.statusCode})');
    }
  }

  /// Creates a challenge against the Lichess AI.
  /// Returns the gameId on success, or throws an exception on failure.
  Future<String> challengeAi({
    required int level,
    required int clockLimit,
    required int clockIncrement,
    required String color,
  }) async {
    if (_accessToken == null) {
      throw Exception('Not authenticated with Lichess.');
    }

    final client = clientFactory();
    final uri = Uri.parse('https://lichess.org/api/challenge/ai');
    final request = await client.postUrl(uri);

    request.headers.set(
      'User-Agent',
      'BlindChess/1.0.0 (contact: support@blindchess.org)',
    );
    request.headers.set('Authorization', 'Bearer $_accessToken');
    request.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
    );

    final body =
        'level=$level'
        '&clock.limit=$clockLimit'
        '&clock.increment=$clockIncrement'
        '&color=$color'
        '&variant=standard';

    request.write(body);

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
    if (isSuccess) {
      final data = json.decode(responseBody);
      final gameId = data['id'] as String?;
      if (gameId != null && gameId.isNotEmpty) {
        return gameId;
      }
      throw Exception('Lichess response did not contain a valid game ID.');
    } else {
      String errMsg = 'HTTP ${response.statusCode}';
      try {
        final errData = json.decode(responseBody);
        if (errData['error'] != null) {
          errMsg = errData['error'].toString();
        }
      } catch (_) {}
      throw Exception('Failed to challenge AI: $errMsg');
    }
  }

  /// Transmits a legal move (in UCI format) to the Lichess board API.
  Future<void> sendMove(String gameId, String move) async {
    if (_accessToken == null) {
      throw Exception('Not authenticated with Lichess.');
    }

    final client = clientFactory();
    final uri = Uri.parse(
      'https://lichess.org/api/board/game/$gameId/move/$move',
    );
    final request = await client.postUrl(uri);

    request.headers.set(
      'User-Agent',
      'BlindChess/1.0.0 (contact: support@blindchess.org)',
    );
    request.headers.set('Authorization', 'Bearer $_accessToken');

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    } else {
      String errMsg = 'HTTP ${response.statusCode}';
      try {
        final errData = json.decode(responseBody);
        if (errData['error'] != null) {
          errMsg = errData['error'].toString();
        }
      } catch (_) {}
      throw Exception(errMsg);
    }
  }

  /// Forfeits the game, resulting in a loss.
  Future<void> resignGame(String gameId) async {
    if (_accessToken == null) {
      throw Exception('Not authenticated with Lichess.');
    }

    final client = clientFactory();
    final uri = Uri.parse('https://lichess.org/api/board/game/$gameId/resign');
    final request = await client.postUrl(uri);

    request.headers.set(
      'User-Agent',
      'BlindChess/1.0.0 (contact: support@blindchess.org)',
    );
    request.headers.set('Authorization', 'Bearer $_accessToken');

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    } else {
      String errMsg = 'HTTP ${response.statusCode}';
      try {
        final errData = json.decode(responseBody);
        if (errData['error'] != null) {
          errMsg = errData['error'].toString();
        }
      } catch (_) {}
      throw Exception(errMsg);
    }
  }

  /// Requests a takeback (undo) on Lichess.
  Future<void> requestTakeback(String gameId) async {
    if (_accessToken == null) {
      throw Exception('Not authenticated with Lichess.');
    }

    final client = clientFactory();
    final uri = Uri.parse(
      'https://lichess.org/api/board/game/$gameId/takeback/yes',
    );
    final request = await client.postUrl(uri);

    request.headers.set(
      'User-Agent',
      'BlindChess/1.0.0 (contact: support@blindchess.org)',
    );
    request.headers.set('Authorization', 'Bearer $_accessToken');

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    } else {
      String errMsg = 'HTTP ${response.statusCode}';
      try {
        final errData = json.decode(responseBody);
        if (errData['error'] != null) {
          errMsg = errData['error'].toString();
        }
      } catch (_) {}
      throw Exception(errMsg);
    }
  }

  /// Ends the game without a result, only valid before both players make their first move.
  Future<void> abortGame(String gameId) async {
    if (_accessToken == null) {
      throw Exception('Not authenticated with Lichess.');
    }

    final client = clientFactory();
    final uri = Uri.parse('https://lichess.org/api/board/game/$gameId/abort');
    final request = await client.postUrl(uri);

    request.headers.set(
      'User-Agent',
      'BlindChess/1.0.0 (contact: support@blindchess.org)',
    );
    request.headers.set('Authorization', 'Bearer $_accessToken');

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    } else {
      String errMsg = 'HTTP ${response.statusCode}';
      try {
        final errData = json.decode(responseBody);
        if (errData['error'] != null) {
          errMsg = errData['error'].toString();
        }
      } catch (_) {}
      throw Exception(errMsg);
    }
  }

  /// Offers or accepts a draw (accept = true -> /draw/yes, accept = false -> /draw/no).
  Future<void> drawGame(String gameId, bool accept) async {
    if (_accessToken == null) {
      throw Exception('Not authenticated with Lichess.');
    }

    final client = clientFactory();
    final acceptPath = accept ? 'yes' : 'no';
    final uri = Uri.parse(
      'https://lichess.org/api/board/game/$gameId/draw/$acceptPath',
    );
    final request = await client.postUrl(uri);

    request.headers.set(
      'User-Agent',
      'BlindChess/1.0.0 (contact: support@blindchess.org)',
    );
    request.headers.set('Authorization', 'Bearer $_accessToken');

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    } else {
      String errMsg = 'HTTP ${response.statusCode}';
      try {
        final errData = json.decode(responseBody);
        if (errData['error'] != null) {
          errMsg = errData['error'].toString();
        }
      } catch (_) {}
      throw Exception(errMsg);
    }
  }

  /// Opens a long-lived connection to stream board game events (NDJSON).
  /// Returns a stream of events as decoded JSON maps.
  Stream<Map<String, dynamic>> streamGameState(String gameId) {
    if (_accessToken == null) {
      throw Exception('Not authenticated with Lichess.');
    }

    final controller = StreamController<Map<String, dynamic>>();
    HttpClient? client;
    HttpClientRequest? request;
    HttpClientResponse? response;
    StreamSubscription? subscription;

    void cleanup() {
      subscription?.cancel();
      try {
        client?.close(force: true);
      } catch (_) {}
    }

    controller.onCancel = cleanup;

    controller.onListen = () async {
      try {
        client = clientFactory();
        final uri = Uri.parse(
          'https://lichess.org/api/board/game/stream/$gameId',
        );
        request = await client!.getUrl(uri);
        request!.headers.set(
          'User-Agent',
          'BlindChess/1.0.0 (contact: support@blindchess.org)',
        );
        request!.headers.set('Authorization', 'Bearer $_accessToken');
        request!.headers.set('Accept', 'application/x-ndjson');

        response = await request!.close();

        if (response!.statusCode < 200 || response!.statusCode >= 300) {
          final responseBody = await response!
              .transform(utf8.decoder)
              .join()
              .timeout(
                const Duration(seconds: 3),
                onTimeout: () => 'Timeout retrieving error body',
              );
          String errMsg = 'HTTP ${response!.statusCode}';
          try {
            final errData = json.decode(responseBody);
            if (errData['error'] != null) {
              errMsg = errData['error'].toString();
            }
          } catch (_) {}
          controller.addError(Exception('Failed to stream game: $errMsg'));
          controller.close();
          return;
        }

        subscription = response!
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                final trimmed = line.trim();
                if (trimmed.isEmpty) return; // Skip keep-alive newlines
                try {
                  final data = json.decode(trimmed);
                  if (data is Map<String, dynamic>) {
                    controller.add(data);
                  }
                } catch (e) {
                  debugPrint(
                    'Failed to parse NDJSON line: $trimmed, error: $e',
                  );
                }
              },
              onError: (error) {
                if (!controller.isClosed) {
                  controller.addError(error);
                }
              },
              onDone: () {
                if (!controller.isClosed) {
                  controller.close();
                }
              },
              cancelOnError: true,
            );
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
          controller.close();
        }
      }
    };

    return controller.stream;
  }
}
