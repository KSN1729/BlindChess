import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service coordinating Lichess OAuth2 PKCE login & token exchange.
class LichessAuthService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription? _linkSubscription;

  /// HTTP client factory to instantiate HttpClient instances (overridable in tests).
  HttpClient Function() clientFactory;

  /// Callback triggered when an authorization code is successfully exchanged for a token.
  final Future<void> Function(String token) onTokenExchanged;

  /// Callback triggered when authentication fails with a description error.
  final void Function(String error) onError;

  /// Callback triggered when authentication begins.
  final void Function() onAuthStarted;

  /// Callback to check if authentication is currently active.
  final bool Function() isAuthenticating;

  LichessAuthService({
    required this.onTokenExchanged,
    required this.onError,
    required this.onAuthStarted,
    required this.isAuthenticating,
    HttpClient Function()? clientFactory,
  }) : clientFactory = clientFactory ?? (() => HttpClient());

  // OAuth State Variables
  String? _currentVerifier;
  String? _currentState;
  Timer? _authTimer;

  /// Starts listening to deep-link redirects.
  void initRedirectListener() {
    _linkSubscription?.cancel();
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) => handleIncomingUri(uri),
      onError: (err) {
        onError('Redirect listener failure: $err');
      },
    );
  }

  /// Disposes deep link listeners.
  void dispose() {
    _linkSubscription?.cancel();
    _authTimer?.cancel();
    _currentState = null;
    _currentVerifier = null;
  }

  /// Initiates browser PKCE authorization.
  Future<void> login() async {
    _authTimer?.cancel();
    onAuthStarted();

    final verifier = _generateCodeVerifier();
    final challenge = _generateCodeChallenge(verifier);
    final state = _generateState();

    _currentVerifier = verifier;
    _currentState = state;

    // 2-minute safety timeout
    _authTimer = Timer(const Duration(minutes: 2), () {
      _authTimer = null;
      onError('Authentication connection timed out.');
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
      final success = await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      if (!success) {
        throw Exception('launchUrl returned false');
      }
    } catch (e) {
      _authTimer?.cancel();
      _authTimer = null;
      onError('Failed to launch system browser: $e');
    }
  }

  /// Directly process an incoming callback URI.
  Future<void> handleIncomingUri(Uri uri) async {
    if (uri.scheme != 'org.blindchess.app' || uri.host != 'oauth-callback') {
      return;
    }

    final error = uri.queryParameters['error'];
    if (error != null) {
      _authTimer?.cancel();
      _authTimer = null;
      if (error == 'access_denied') {
        onError('Lichess authorization was declined.');
      } else {
        onError('Lichess authentication error: $error');
      }
      return;
    }

    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];

    if (code == null || state == null) {
      _authTimer?.cancel();
      _authTimer = null;
      onError('Malformed authorization response.');
      return;
    }

    var stateToVerify = _currentState;
    var verifierToUse = _currentVerifier;

    if (stateToVerify == null || verifierToUse == null) {
      if (isAuthenticating()) {
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      stateToVerify ??= prefs.getString('lichess_oauth_state');
      verifierToUse ??= prefs.getString('lichess_oauth_verifier');
    }

    if (stateToVerify == null || verifierToUse == null) {
      _authTimer?.cancel();
      _authTimer = null;
      onError('Security verification state mismatch.');
      return;
    }

    if (stateToVerify != state) {
      _authTimer?.cancel();
      _authTimer = null;
      onError('Security verification state mismatch.');
      return;
    }

    final verifier = verifierToUse;
    _currentState = null;
    _currentVerifier = null;
    _authTimer?.cancel();
    _authTimer = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lichess_oauth_state');
    await prefs.remove('lichess_oauth_verifier');

    await _exchangeCodeForToken(code, verifier);
  }

  /// Test-only completer to pause token exchange and prevent race conditions.
  static Completer<void>? testDelayCompleter;

  Future<void> _exchangeCodeForToken(String code, String codeVerifier) async {
    try {
      if (testDelayCompleter != null) {
        await testDelayCompleter!.future;
      }
      final client = clientFactory();
      final request = await client.postUrl(
        Uri.parse('https://lichess.org/api/token'),
      );

      request.headers.set('User-Agent', 'BlindChess/1.0.0 (contact: support@blindchess.org)');
      request.headers.contentType = ContentType('application', 'x-www-form-urlencoded');

      final body =
          'grant_type=authorization_code'
          '&code=$code'
          '&code_verifier=$codeVerifier'
          '&redirect_uri=org.blindchess.app://oauth-callback'
          '&client_id=blindchess';

      request.write(body);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(responseBody);
        final token = data['access_token'] as String?;
        if (token != null && token.isNotEmpty) {
          await onTokenExchanged(token);
        } else {
          onError('Response from Lichess did not contain access token.');
        }
      } else {
        onError('Lichess token exchange failed (HTTP ${response.statusCode}).');
      }
    } catch (e) {
      onError('Network error during token exchange: $e');
    }
  }

  // --- PKCE Helpers ---

  String _generateCodeVerifier() {
    final random = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    return List.generate(
      80,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = ascii.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  String _generateState() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(
      16,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }
}
