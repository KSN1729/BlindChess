import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blind_chess/services/lichess_service.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:blind_chess/models/lichess_game.dart';
import 'package:blind_chess/screens/recent_games_screen.dart';
import 'package:blind_chess/widgets/chess_square.dart';
import 'package:chess/chess.dart' as chess;
import 'package:blind_chess/screens/home_screen.dart';
import 'package:blind_chess/widgets/challenge_bot_dialog.dart';
import 'package:blind_chess/screens/live_game_screen.dart';
import 'package:blind_chess/services/settings_service.dart';
import 'package:blind_chess/services/statistics_service.dart';
import 'package:blind_chess/screens/stats_screen.dart';
import 'package:blind_chess/main.dart';
import 'package:blind_chess/widgets/chess_board.dart';

class MockUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  String? launchedUrl;

  @override
  Null get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrl = url;
    return true;
  }

  @override
  Future<bool> canLaunch(String url) async => true;
}

// Lightweight mock hierarchy using noSuchMethod to satisfy standard HttpClient contracts
class MockHttpClient implements HttpClient {
  final MockHttpClientRequest request = MockHttpClientRequest();

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => request;

  @override
  Future<HttpClientRequest> postUrl(Uri url) async => request;

  @override
  void noSuchMethod(Invocation invocation) {}
}

class MockHttpClientRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = MockHttpHeaders();

  @override
  void write(Object? obj) {}

  @override
  Future<HttpClientResponse> close() async => MockHttpClientResponse();

  @override
  void noSuchMethod(Invocation invocation) {}
}

class MockHttpHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  set contentType(ContentType? type) {}

  @override
  void noSuchMethod(Invocation invocation) {}
}

class MockHttpClientResponse implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) {
    final jsonString = json.encode({
      'username': 'MockLichessUser',
      'perfs': {
        'blitz': {'rating': 1700},
        'rapid': {'rating': 1900},
      },
      'count': {'all': 250, 'win': 130, 'loss': 100, 'draw': 20},
    });
    final bytes = utf8.encode(jsonString);
    return Stream<List<int>>.fromIterable([bytes]).transform(streamTransformer);
  }

  @override
  void noSuchMethod(Invocation invocation) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LichessService PKCE and Auth Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SettingsService.instance.resetToDefaults();
      // Restore default clientFactory
      LichessService.instance.clientFactory = () => HttpClient();
    });

    test('LichessService initialization with no saved credentials', () async {
      final service = LichessService.instance;
      await service.init();
      expect(service.isAuthenticated, isFalse);
      expect(service.username, isNull);
      expect(service.accessToken, isNull);
    });

    test('LichessService initialization with cached credentials', () async {
      SharedPreferences.setMockInitialValues({
        'lichess_access_token': 'test_token_123',
        'lichess_username': 'LichessUser',
        'lichess_blitz_rating': 1650,
        'lichess_rapid_rating': 1800,
        'lichess_games_played': 120,
        'lichess_wins': 65,
        'lichess_losses': 45,
        'lichess_draws': 10,
      });

      final service = LichessService.instance;
      await service.init();
      expect(service.isAuthenticated, isTrue);
      expect(service.accessToken, 'test_token_123');
      expect(service.username, 'LichessUser');
      expect(service.blitzRating, 1650);
      expect(service.rapidRating, 1800);
      expect(service.gamesPlayed, 120);
      expect(service.wins, 65);
      expect(service.losses, 45);
      expect(service.draws, 10);
    });

    test('Lichess Recent Games - NDJSON Parsing Test', () {
      const mockNdjson =
          '{"id":"game1","createdAt":1609459200000,"players":{"white":{"user":{"name":"MockLichessUser","id":"mocklichessuser"}},"black":{"user":{"name":"OpponentPlayer","id":"opponentplayer"}}},"winner":"white","status":"mate"}\n'
          '{"id":"game2","createdAt":1609462800000,"players":{"white":{"user":{"name":"AnotherOpponent","id":"anotheropponent"}},"black":{"user":{"name":"MockLichessUser","id":"mocklichessuser"}}},"winner":"white","status":"resign"}';

      final games = <LichessGame>[];
      final lines = mockNdjson.split('\n');
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        games.add(LichessGame.fromJson(json.decode(line), 'MockLichessUser'));
      }

      expect(games.length, 2);
      expect(games[0].id, 'game1');
      expect(games[0].opponentUsername, 'OpponentPlayer');
      expect(games[0].colorPlayed, 'White');
      expect(games[0].result, 'Win');
      expect(games[0].date, DateTime.fromMillisecondsSinceEpoch(1609459200000));

      expect(games[1].id, 'game2');
      expect(games[1].opponentUsername, 'AnotherOpponent');
      expect(games[1].colorPlayed, 'Black');
      expect(games[1].result, 'Loss');
      expect(games[1].date, DateTime.fromMillisecondsSinceEpoch(1609462800000));
    });

    testWidgets('RecentGamesScreen - Empty state shows message', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'lichess_access_token': 'mock_token',
        'lichess_username': 'MockLichessUser',
      });
      final service = LichessService.instance;
      await service.init();

      // Mock an empty games response
      final mockResponse = MockGamesListResponse('');
      final mockClient = MockCustomHttpClient(MockCustomRequest(mockResponse));
      service.clientFactory = () => mockClient;

      await tester.pumpWidget(const MaterialApp(home: RecentGamesScreen()));

      // Wait for loading to finish
      await tester.pump(); // Start loading
      await tester.pump(const Duration(milliseconds: 100)); // Finish loading

      expect(
        find.text('No recent games found on this Lichess account.'),
        findsOneWidget,
      );
    });

    testWidgets('RecentGamesScreen - Error state displays retry button', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'lichess_access_token': 'mock_token',
        'lichess_username': 'MockLichessUser',
      });
      final service = LichessService.instance;
      await service.init();

      // Mock error response (e.g. 500 internal server error)
      final mockResponse = MockGamesListResponse('', statusCode: 500);
      final mockClient = MockCustomHttpClient(MockCustomRequest(mockResponse));
      service.clientFactory = () => mockClient;

      await tester.pumpWidget(const MaterialApp(home: RecentGamesScreen()));

      await tester.pump(); // Start loading
      await tester.pump(const Duration(milliseconds: 100)); // Finish loading

      expect(find.textContaining('Failed to load games:'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
    });

    testWidgets(
      'RecentGamesScreen - Tapping game loads PGN lazily and handles caching',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
          'lichess_username': 'MockLichessUser',
        });
        final service = LichessService.instance;
        await service.init();

        // Keep track of requested URLs
        final requestedUrls = <String>[];

        // Custom mock client to track URL requests
        service.clientFactory = () {
          return MockTrackingClient(requestedUrls);
        };

        await tester.pumpWidget(const MaterialApp(home: RecentGamesScreen()));

        await tester.pump(); // Start loading games
        await tester.pump(
          const Duration(milliseconds: 100),
        ); // Finish loading games

        // Verify the list has rendered the game items
        expect(find.text('vs. OpponentPlayer'), findsOneWidget);
        expect(find.text('vs. Opponent2'), findsOneWidget);

        // Verify that the recent games endpoint was called with max=15 query parameter
        expect(
          requestedUrls.any(
            (url) => url.contains('/api/games/user/') && url.contains('max=15'),
          ),
          isTrue,
        );

        // Verify that NO PGN has been fetched yet (proving lazy loading starts as false/unrequested)
        expect(
          requestedUrls.where((url) => url.contains('/game/export/')).length,
          0,
        );

        // Tap on the game tile to trigger navigation to PgnReplayScreen
        await tester.tap(find.text('vs. OpponentPlayer'));
        await tester.pump(); // Start transition
        await tester.pump(); // Build PgnReplayScreen frame

        // Verify loading indicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Verify PGN is requested
        expect(
          requestedUrls
              .where((url) => url.contains('/game/export/game123.pgn'))
              .length,
          1,
        );

        // Complete PGN loading
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Verify Replay Screen details are visible
        expect(find.text('vs. OpponentPlayer'), findsOneWidget);
        expect(
          find.text('Starting Position  |  Total: 3 half-moves'),
          findsOneWidget,
        );

        // Verify playback controls are visible
        final firstFinder = find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'First Move',
        );
        final prevFinder = find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Previous',
        );
        final nextFinder = find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Next',
        );
        final lastFinder = find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Last Move',
        );

        expect(firstFinder, findsOneWidget);
        expect(prevFinder, findsOneWidget);
        expect(nextFinder, findsOneWidget);
        expect(lastFinder, findsOneWidget);

        // Check button states (Previous and First Move are disabled at game start)
        final IconButton firstBtn = tester.widget(firstFinder);
        final IconButton prevBtn = tester.widget(prevFinder);
        expect(firstBtn.onPressed, isNull);
        expect(prevBtn.onPressed, isNull);

        // Tap Next to step forward to move 1
        await tester.ensureVisible(nextFinder);
        await tester.tap(nextFinder);
        await tester.pump();
        expect(
          find.text('Move 1 (White: e4)  |  Total: 3 half-moves'),
          findsOneWidget,
        );

        // Tap Next again
        await tester.ensureVisible(nextFinder);
        await tester.tap(nextFinder);
        await tester.pump();
        expect(
          find.text('Move 1 (Black: e5)  |  Total: 3 half-moves'),
          findsOneWidget,
        );

        // Tap Previous
        await tester.ensureVisible(prevFinder);
        await tester.tap(prevFinder);
        await tester.pump();
        expect(
          find.text('Move 1 (White: e4)  |  Total: 3 half-moves'),
          findsOneWidget,
        );

        // Tap Last Move to jump to final position
        await tester.ensureVisible(lastFinder);
        await tester.tap(lastFinder);
        await tester.pump();
        expect(
          find.text('Move 2 (White: Nf3)  |  Total: 3 half-moves'),
          findsOneWidget,
        );

        // Check Next and Last buttons are disabled at game end
        final IconButton nextBtn = tester.widget(nextFinder);
        final IconButton lastBtn = tester.widget(lastFinder);
        expect(nextBtn.onPressed, isNull);
        expect(lastBtn.onPressed, isNull);

        // Tap First Move to jump back to start
        await tester.ensureVisible(firstFinder);
        await tester.tap(firstFinder);
        await tester.pump();
        expect(
          find.text('Starting Position  |  Total: 3 half-moves'),
          findsOneWidget,
        );

        // Read-only tap test: tap on square E2
        // Tapping should not select it or show selection highlights
        await tester.tap(
          find.byWidgetPredicate((w) => w is ChessSquare && w.label == 'E2'),
        );
        await tester.pump();

        // Go back to list screen
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        // Tap the game tile again to confirm caching works
        await tester.tap(find.text('vs. OpponentPlayer'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Request count should still be exactly 1
        expect(
          requestedUrls
              .where((url) => url.contains('/game/export/game123.pgn'))
              .length,
          1,
        );
      },
    );

    test('Lichess Recent Games - PGN comment annotations stripping test', () {
      const rawPgn =
          '[Event "Rated Blitz game"]\n[Site "https://lichess.org/"]\n[Date "2023.01.01"]\n[White "Player1"]\n[Black "Player2"]\n[Result "1-0"]\n\n1. e4 { [%eval 0.15] [%clk 0:03:00] } e5 { [%clk 0:03:00] } 2. Nf3 { [%eval 0.25] [%clk 0:02:58] } 1-0';

      final commentStripped = rawPgn.replaceAll(
        RegExp(r'\{[^}]*\}', multiLine: true, dotAll: true),
        '',
      );

      final lines = commentStripped.split(RegExp(r'\r?\n'));
      final normalizedLines = <String>[];
      for (var line in lines) {
        final trimmed = line.trim().replaceAll(RegExp(r'[ \t]+'), ' ');
        if (trimmed.isNotEmpty) {
          normalizedLines.add(trimmed);
        }
      }
      final cleaned = normalizedLines.join('\n');

      final tempChess = chess.Chess();
      expect(tempChess.load_pgn(cleaned), isTrue);
      expect(tempChess.getHistory(), ['e4', 'e5', 'Nf3']);
    });

    test('LichessService logout clears all cached preferences', () async {
      SharedPreferences.setMockInitialValues({
        'lichess_access_token': 'test_token_123',
        'lichess_username': 'LichessUser',
        'lichess_blitz_rating': 1650,
        'lichess_rapid_rating': 1800,
        'lichess_games_played': 120,
        'lichess_wins': 65,
        'lichess_losses': 45,
        'lichess_draws': 10,
      });

      final service = LichessService.instance;
      await service.init();
      expect(service.isAuthenticated, isTrue);

      await service.logout();
      expect(service.isAuthenticated, isFalse);
      expect(service.accessToken, isNull);
      expect(service.username, isNull);
      expect(service.blitzRating, isNull);
      expect(service.rapidRating, isNull);
      expect(service.gamesPlayed, isNull);
      expect(service.wins, isNull);
      expect(service.losses, isNull);
      expect(service.draws, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('lichess_access_token'), isFalse);
      expect(prefs.containsKey('lichess_games_played'), isFalse);
    });

    test(
      'LichessService login initiates OAuth with correct redirect URI',
      () async {
        final mockLauncher = MockUrlLauncher();
        UrlLauncherPlatform.instance = mockLauncher;

        final service = LichessService.instance;
        await service.login();

        expect(mockLauncher.launchedUrl, isNotNull);
        final uri = Uri.parse(mockLauncher.launchedUrl!);
        expect(
          uri.queryParameters['redirect_uri'],
          'org.blindchess.app://oauth-callback',
        );
        expect(uri.queryParameters['client_id'], 'blindchess');
        expect(uri.queryParameters['code_challenge_method'], 'S256');
      },
    );

    test('LichessService login timeout resets state', () {
      fakeAsync((async) {
        final mockLauncher = MockUrlLauncher();
        UrlLauncherPlatform.instance = mockLauncher;

        final service = LichessService.instance;
        service.login();

        expect(service.isAuthenticatingNotifier.value, isTrue);
        expect(service.errorMessageNotifier.value, isNull);

        // Elapse 120 seconds (2 minutes)
        async.elapse(const Duration(seconds: 120));

        expect(service.isAuthenticatingNotifier.value, isFalse);
        expect(service.errorMessageNotifier.value, contains('timed out'));
      });
    });

    test(
      'LichessService handleIncomingUri handles access_denied error',
      () async {
        final service = LichessService.instance;
        service.isAuthenticatingNotifier.value = true;
        service.errorMessageNotifier.value = null;

        final errorUri = Uri.parse(
          'org.blindchess.app://oauth-callback?error=access_denied',
        );
        await service.handleIncomingUri(errorUri);

        expect(service.isAuthenticatingNotifier.value, isFalse);
        expect(service.errorMessageNotifier.value, contains('declined'));
      },
    );

    test(
      'LichessService handleIncomingUri ignores duplicate calls when authenticating',
      () async {
        final service = LichessService.instance;
        service.isAuthenticatingNotifier.value = true;
        service.errorMessageNotifier.value = null;
        service.isAuthenticatedNotifier.value = false;

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lichess_oauth_state', 'state_123');
        await prefs.setString('lichess_oauth_verifier', 'verifier_456');

        final successUri = Uri.parse(
          'org.blindchess.app://oauth-callback?code=code_abc&state=state_123',
        );

        // First call consumes state/verifier and starts exchange
        final mockClient = MockHttpClient();
        service.clientFactory = () => mockClient;

        // Initiate call without awaiting so we can test parallel/duplicate call
        final firstFuture = service.handleIncomingUri(successUri);

        // Second call happens immediately while exchange is active
        await service.handleIncomingUri(successUri);

        // Verify that the second call did not reset authentication state or set error messages
        expect(service.isAuthenticatingNotifier.value, isTrue);
        expect(service.errorMessageNotifier.value, isNull);

        await firstFuture;
      },
    );

    testWidgets(
      'MaterialApp onGenerateRoute intercepts deep link and returns HomeScreen route',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MyApp());
        final state = tester.state<NavigatorState>(find.byType(Navigator));

        final route = state.widget.onGenerateRoute!(
          const RouteSettings(name: '/?code=auth_code_123&state=state_abc'),
        );

        expect(route, isNotNull);
        final pageRoute = route as MaterialPageRoute;
        final widget = pageRoute.builder(state.context);
        expect(widget, isA<HomeScreen>());
      },
    );

    test(
      'LichessService loadProfile parses user stats count correctly',
      () async {
        final service = LichessService.instance;
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
        });
        await service.init();

        final mockClient = MockHttpClient();
        service.clientFactory = () => mockClient;

        await service.loadProfile();

        expect(service.username, 'MockLichessUser');
        expect(service.blitzRating, 1700);
        expect(service.rapidRating, 1900);
        expect(service.gamesPlayed, 250);
        expect(service.wins, 130);
        expect(service.losses, 100);
        expect(service.draws, 20);

        // Verify SharedPreferences persistence
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('lichess_username'), 'MockLichessUser');
        expect(prefs.getInt('lichess_games_played'), 250);
        expect(prefs.getInt('lichess_wins'), 130);
        expect(prefs.getInt('lichess_losses'), 100);
        expect(prefs.getInt('lichess_draws'), 20);
      },
    );

    test('LichessService challengeAi constructs correct request', () async {
      final service = LichessService.instance;
      SharedPreferences.setMockInitialValues({
        'lichess_access_token': 'test_bearer_token',
      });
      await service.init();

      final mockResp = MockChallengeResponse(
        '{"id": "gameId789", "url": "https://lichess.org/gameId789"}',
      );
      final mockReq = MockChallengeRequest(mockResp);
      final mockClient = MockChallengeHttpClient(mockReq);
      service.clientFactory = () => mockClient;

      final gameId = await service.challengeAi(
        level: 3,
        clockLimit: 300,
        clockIncrement: 0,
        color: 'white',
      );

      expect(gameId, 'gameId789');
      expect(mockClient.requestedUrls, [
        'https://lichess.org/api/challenge/ai',
      ]);

      expect(mockReq.writtenBodies.length, 1);
      final body = mockReq.writtenBodies.first;
      expect(body, contains('level=3'));
      expect(body, contains('clock.limit=300'));
      expect(body, contains('clock.increment=0'));
      expect(body, contains('color=white'));
      expect(body, contains('variant=standard'));
    });

    test(
      'LichessService challengeAi works with HTTP 201 Created response',
      () async {
        final service = LichessService.instance;
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'test_bearer_token',
        });
        await service.init();

        final mockResp = MockChallengeResponse(
          '{"id": "gameId123", "url": "https://lichess.org/gameId123"}',
          statusCode: 201,
        );
        final mockReq = MockChallengeRequest(mockResp);
        final mockClient = MockChallengeHttpClient(mockReq);
        service.clientFactory = () => mockClient;

        final gameId = await service.challengeAi(
          level: 3,
          clockLimit: 300,
          clockIncrement: 0,
          color: 'white',
        );

        expect(gameId, 'gameId123');
        expect(mockClient.requestedUrls, [
          'https://lichess.org/api/challenge/ai',
        ]);
      },
    );

    test('LichessService loadProfile success with HTTP 201 response', () async {
      final service = LichessService.instance;
      SharedPreferences.setMockInitialValues({
        'lichess_access_token': 'mock_token',
      });
      await service.init();

      final mockResp = MockChallengeResponse(
        json.encode({
          'username': 'MockLichessUser201',
          'perfs': {
            'blitz': {'rating': 1701},
            'rapid': {'rating': 1901},
          },
          'count': {'all': 251, 'win': 131, 'loss': 100, 'draw': 20},
        }),
        statusCode: 201,
      );
      final mockReq = MockChallengeRequest(mockResp);
      final mockClient = MockChallengeHttpClient(mockReq);
      service.clientFactory = () => mockClient;

      await service.loadProfile();
      expect(service.username, 'MockLichessUser201');
      expect(service.blitzRating, 1701);
      expect(service.gamesPlayed, 251);
    });

    test(
      'LichessService fetchRecentGames success with HTTP 201 response',
      () async {
        final service = LichessService.instance;
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
          'lichess_username': 'MockLichessUser',
        });
        await service.init();

        final mockResp = MockChallengeResponse(
          '{"id":"game201","createdAt":1609459200000,"players":{"white":{"user":{"name":"MockLichessUser"}},"black":{"user":{"name":"OpponentPlayer"}}},"winner":"white","status":"mate"}',
          statusCode: 201,
        );
        final mockReq = MockChallengeRequest(mockResp);
        final mockClient = MockChallengeHttpClient(mockReq);
        service.clientFactory = () => mockClient;

        final games = await service.fetchRecentGames(max: 1);
        expect(games.length, 1);
        expect(games[0].id, 'game201');
      },
    );

    test(
      'LichessService fetchGamePgn success with HTTP 201 response',
      () async {
        final service = LichessService.instance;
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
        });
        await service.init();

        final mockResp = MockChallengeResponse(
          '1. e4 e5 2. Nf3',
          statusCode: 201,
        );
        final mockReq = MockChallengeRequest(mockResp);
        final mockClient = MockChallengeHttpClient(mockReq);
        service.clientFactory = () => mockClient;

        final pgn = await service.fetchGamePgn('game201');
        expect(pgn, '1. e4 e5 2. Nf3');
      },
    );

    test(
      'LichessService sendMove handles 200, 201, 204 success and failure',
      () async {
        final service = LichessService.instance;
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
        });
        await service.init();

        for (final code in [200, 201, 204]) {
          final mockResp = MockChallengeResponse(
            '{"ok": true}',
            statusCode: code,
          );
          final mockReq = MockChallengeRequest(mockResp);
          final mockClient = MockChallengeHttpClient(mockReq);
          service.clientFactory = () => mockClient;

          // Should not throw exception
          await service.sendMove('gameId', 'e2e4');
        }

        // Test failure response
        final mockRespFail = MockChallengeResponse(
          '{"error": "Not player turn"}',
          statusCode: 400,
        );
        final mockReqFail = MockChallengeRequest(mockRespFail);
        final mockClientFail = MockChallengeHttpClient(mockReqFail);
        service.clientFactory = () => mockClientFail;

        expect(
          () => service.sendMove('gameId', 'e2e4'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Not player turn'),
            ),
          ),
        );
      },
    );

    test(
      'LichessService resignGame handles 200, 201, 204 success and failure',
      () async {
        final service = LichessService.instance;
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
        });
        await service.init();

        for (final code in [200, 201, 204]) {
          final mockResp = MockChallengeResponse(
            '{"ok": true}',
            statusCode: code,
          );
          final mockReq = MockChallengeRequest(mockResp);
          final mockClient = MockChallengeHttpClient(mockReq);
          service.clientFactory = () => mockClient;

          // Should not throw exception
          await service.resignGame('gameId');
        }

        // Test failure response
        final mockRespFail = MockChallengeResponse(
          '{"error": "Game already finished"}',
          statusCode: 400,
        );
        final mockReqFail = MockChallengeRequest(mockRespFail);
        final mockClientFail = MockChallengeHttpClient(mockReqFail);
        service.clientFactory = () => mockClientFail;

        expect(
          () => service.resignGame('gameId'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Game already finished'),
            ),
          ),
        );
      },
    );

    test(
      'LichessService abortGame handles 200, 201, 204 success and failure',
      () async {
        final service = LichessService.instance;
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
        });
        await service.init();

        for (final code in [200, 201, 204]) {
          final mockResp = MockChallengeResponse(
            '{"ok": true}',
            statusCode: code,
          );
          final mockReq = MockChallengeRequest(mockResp);
          final mockClient = MockChallengeHttpClient(mockReq);
          service.clientFactory = () => mockClient;

          // Should not throw exception
          await service.abortGame('gameId');
        }

        // Test failure response
        final mockRespFail = MockChallengeResponse(
          '{"error": "Cannot abort now"}',
          statusCode: 400,
        );
        final mockReqFail = MockChallengeRequest(mockRespFail);
        final mockClientFail = MockChallengeHttpClient(mockReqFail);
        service.clientFactory = () => mockClientFail;

        expect(
          () => service.abortGame('gameId'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Cannot abort now'),
            ),
          ),
        );
      },
    );

    test(
      'LichessService drawGame handles 200, 201, 204 success and failure',
      () async {
        final service = LichessService.instance;
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
        });
        await service.init();

        for (final code in [200, 201, 204]) {
          final mockResp = MockChallengeResponse(
            '{"ok": true}',
            statusCode: code,
          );
          final mockReq = MockChallengeRequest(mockResp);
          final mockClient = MockChallengeHttpClient(mockReq);
          service.clientFactory = () => mockClient;

          // Should not throw exception
          await service.drawGame('gameId', true);
        }

        // Test failure response
        final mockRespFail = MockChallengeResponse(
          '{"error": "No draw offer"}',
          statusCode: 400,
        );
        final mockReqFail = MockChallengeRequest(mockRespFail);
        final mockClientFail = MockChallengeHttpClient(mockReqFail);
        service.clientFactory = () => mockClientFail;

        expect(
          () => service.drawGame('gameId', true),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('No draw offer'),
            ),
          ),
        );
      },
    );

    testWidgets('HomeScreen - Challenge Bot Success Flow', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'lichess_access_token': 'mock_token',
        'lichess_username': 'MockLichessUser',
      });
      final service = LichessService.instance;
      await service.init();

      final streamController = StreamController<List<int>>();
      final streamResp = MockStreamResponse(
        streamController.stream.asBroadcastStream(),
      );
      final streamReq = MockStreamRequest(streamResp);

      final challengeResp = MockChallengeResponse(
        '{"id": "testGameId", "url": "https://lichess.org/testGameId"}',
      );
      final challengeReq = MockChallengeRequest(challengeResp);

      final mockClient = MockCombinedHttpClient(
        postRequest: challengeReq,
        getRequest: streamReq,
      );
      service.clientFactory = () => mockClient;

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

      await tester.pumpAndSettle();
      final playBtn = find.text('Play Lichess Bot');
      expect(playBtn, findsOneWidget);

      await tester.ensureVisible(playBtn);
      await tester.tap(playBtn);
      await tester.pumpAndSettle();

      expect(find.byType(ChallengeBotDialog), findsOneWidget);
      expect(find.text('Challenge Lichess AI'), findsOneWidget);
      expect(find.text('Bot Difficulty Level: 1'), findsOneWidget);
      expect(find.text('White'), findsOneWidget);
      expect(find.text('Random'), findsOneWidget);
      expect(find.text('Black'), findsOneWidget);
      expect(find.text('5+0'), findsOneWidget);

      await tester.tap(find.text('White'));
      await tester.pumpAndSettle();

      final startBtn = find.descendant(
        of: find.byType(ChallengeBotDialog),
        matching: find.text('Start Game'),
      );
      await tester.tap(startBtn);
      await tester.pump(); // Start pending state

      expect(find.text('Creating game on Lichess...'), findsOneWidget);

      final gameFull = {
        'type': 'gameFull',
        'white': {'name': 'MockLichessUser'},
        'black': {'name': 'Stockfish AI'},
        'state': {'moves': 'e2e4', 'status': 'started'},
      };
      streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(ChallengeBotDialog), findsNothing);
      expect(find.text('Challenge Lichess AI'), findsNothing);
      expect(find.byType(LiveGameScreen), findsOneWidget);
      expect(find.text('Lichess Live Game'), findsOneWidget);
      expect(find.text('Stockfish AI'), findsOneWidget);
      expect(
        find.text('Challenge created successfully! Game ID: testGameId'),
        findsOneWidget,
      );

      // Clear SnackBars to prevent hit test obstruction
      ScaffoldMessenger.of(
        tester.element(find.byType(LiveGameScreen)),
      ).clearSnackBars();
      await tester.pumpAndSettle();

      // Tap Exit Game to return to Home Screen
      final exitBtn = find.text('Exit Game');
      await tester.ensureVisible(exitBtn);
      await tester.tap(exitBtn);
      await tester.pumpAndSettle();

      expect(find.byType(LiveGameScreen), findsNothing);
      expect(find.text('Play Lichess Bot'), findsOneWidget);
    });

    testWidgets('HomeScreen - Challenge Bot Failure Flow', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'lichess_access_token': 'mock_token',
        'lichess_username': 'MockLichessUser',
      });
      final service = LichessService.instance;
      await service.init();

      final mockResp = MockChallengeResponse(
        '{"error": "Too many pending challenges"}',
        statusCode: 400,
      );
      final mockReq = MockChallengeRequest(mockResp);
      final mockClient = MockChallengeHttpClient(mockReq);
      service.clientFactory = () => mockClient;

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

      await tester.pumpAndSettle();
      final playBtn = find.text('Play Lichess Bot');
      await tester.ensureVisible(playBtn);
      await tester.tap(playBtn);
      await tester.pumpAndSettle();

      expect(find.byType(ChallengeBotDialog), findsOneWidget);

      final startBtn = find.descendant(
        of: find.byType(ChallengeBotDialog),
        matching: find.text('Start Game'),
      );
      await tester.tap(startBtn);
      await tester.pump(); // Start pending state
      await tester.pumpAndSettle(); // Resolve failure state

      expect(find.text('Challenge Lichess AI'), findsOneWidget);
      expect(
        find.text('Failed to challenge AI: Too many pending challenges'),
        findsOneWidget,
      );
    });

    test(
      'LichessService streamGameState parses gameFull and gameState',
      () async {
        final service = LichessService.instance;
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
        });
        await service.init();

        final streamController = StreamController<List<int>>();
        final mockResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final mockReq = MockStreamRequest(mockResp);
        final mockClient = MockStreamHttpClient(mockReq);
        service.clientFactory = () => mockClient;

        final events = <Map<String, dynamic>>[];
        final sub = service.streamGameState('game123').listen(events.add);

        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {'moves': 'e2e4 e7e5', 'status': 'started'},
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await Future.delayed(const Duration(milliseconds: 10));

        final gameState = {
          'type': 'gameState',
          'moves': 'e2e4 e7e5 g1f3 b8c6',
          'status': 'started',
        };
        streamController.add(utf8.encode('${json.encode(gameState)}\n'));
        await Future.delayed(const Duration(milliseconds: 10));

        await sub.cancel();
        await streamController.close();

        expect(events.length, 2);
        expect(events[0]['type'], 'gameFull');
        expect(events[0]['state']['moves'], 'e2e4 e7e5');
        expect(events[1]['type'], 'gameState');
        expect(events[1]['moves'], 'e2e4 e7e5 g1f3 b8c6');
      },
    );

    testWidgets(
      'LiveGameScreen - Renders board in read-only mode and taps are disabled',
      (WidgetTester tester) async {
        final service = LichessService.instance;
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
          'lichess_username': 'MockLichessUser',
        });
        await service.init();

        final streamController = StreamController<List<int>>();
        final mockResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final mockReq = MockStreamRequest(mockResp);
        final mockClient = MockStreamHttpClient(mockReq);
        service.clientFactory = () => mockClient;

        await tester.pumpWidget(
          const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
        );

        expect(find.text('Loading live game stream...'), findsOneWidget);

        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {'moves': 'e2e4', 'status': 'started'},
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Stockfish AI'), findsOneWidget);
        expect(find.text('Playing as White'), findsOneWidget);
        expect(find.text("Opponent's turn"), findsOneWidget);
        expect(find.text('Moves Played: 1'), findsOneWidget);

        final squareE2 = find.text('E2');
        expect(squareE2, findsOneWidget);

        await tester.ensureVisible(squareE2);
        await tester.tap(squareE2);
        await tester.pumpAndSettle();

        final chessBoard = tester.widget<ChessBoard>(find.byType(ChessBoard));
        expect(chessBoard.readOnly, isTrue);
      },
    );

    testWidgets(
      'LiveGameScreen - Navigating away cancels the stream subscription',
      (WidgetTester tester) async {
        final service = LichessService.instance;
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
          'lichess_username': 'MockLichessUser',
        });
        await service.init();

        bool streamCancelled = false;
        final streamController = StreamController<List<int>>();
        final mockResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
          onCancel: () {
            streamCancelled = true;
          },
        );
        final mockReq = MockStreamRequest(mockResp);
        final mockClient = MockStreamHttpClient(mockReq);
        service.clientFactory = () => mockClient;

        await tester.pumpWidget(
          MaterialApp(
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (context) => const LiveGameScreen(gameId: 'game123'),
              ),
            ),
          ),
        );

        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {'moves': 'e2e4', 'status': 'started'},
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pumpAndSettle();

        final exitBtn = find.text('Exit Game');
        expect(exitBtn, findsOneWidget);

        await tester.tap(exitBtn);
        await tester.pumpAndSettle();

        expect(streamCancelled, isTrue);
      },
    );

    testWidgets('LiveGameScreen - Stream error shows Reconnect UI', (
      WidgetTester tester,
    ) async {
      final service = LichessService.instance;
      SharedPreferences.setMockInitialValues({
        'lichess_access_token': 'mock_token',
        'lichess_username': 'MockLichessUser',
      });
      await service.init();

      final streamController = StreamController<List<int>>();
      final mockResp = MockStreamResponse(
        streamController.stream.asBroadcastStream(),
      );
      final mockReq = MockStreamRequest(mockResp);
      final mockClient = MockStreamHttpClient(mockReq);
      service.clientFactory = () => mockClient;

      await tester.pumpWidget(
        const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
      );

      final gameFull = {
        'type': 'gameFull',
        'white': {'name': 'MockLichessUser'},
        'black': {'name': 'Stockfish AI'},
        'state': {'moves': 'e2e4', 'status': 'started'},
      };
      streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
      await tester.pumpAndSettle();

      streamController.addError(Exception('Network disconnected'));
      await tester.pumpAndSettle();

      expect(find.text('Connection Lost'), findsOneWidget);
      expect(find.text('Network disconnected'), findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);

      await tester.tap(find.text('Reconnect'));
      await tester.pump();
    });

    testWidgets(
      'LiveGameScreen - Player Turn: Tapping piece shows legal moves',
      (WidgetTester tester) async {
        final service = LichessService.instance;
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
          'lichess_username': 'MockLichessUser',
        });
        await service.init();

        final streamController = StreamController<List<int>>();
        final mockResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final mockReq = MockStreamRequest(mockResp);
        final mockClient = MockStreamHttpClient(mockReq);
        service.clientFactory = () => mockClient;

        await tester.pumpWidget(
          const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
        );

        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {'moves': '', 'status': 'started'},
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pump();
        await tester.pumpAndSettle();

        final squareE2 = find.text('E2');
        await tester.ensureVisible(squareE2);
        await tester.tap(squareE2);
        await tester.pumpAndSettle();

        final chessBoard = tester.widget<ChessBoard>(find.byType(ChessBoard));
        expect(chessBoard.selectedSquare, 'E2');
        expect(
          chessBoard.highlightedSquares,
          contains((4, 4)),
        ); // e4 on 0-indexed 8x8 matrix (row 4, col 4 is e4)
      },
    );

    testWidgets('LiveGameScreen - Opponent Turn: Tapping piece does nothing', (
      WidgetTester tester,
    ) async {
      final service = LichessService.instance;
      SharedPreferences.setMockInitialValues({
        'lichess_access_token': 'mock_token',
        'lichess_username': 'MockLichessUser',
      });
      await service.init();

      final streamController = StreamController<List<int>>();
      final mockResp = MockStreamResponse(
        streamController.stream.asBroadcastStream(),
      );
      final mockReq = MockStreamRequest(mockResp);
      final mockClient = MockStreamHttpClient(mockReq);
      service.clientFactory = () => mockClient;

      await tester.pumpWidget(
        const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
      );

      final gameFull = {
        'type': 'gameFull',
        'white': {'name': 'Stockfish AI'},
        'black': {'name': 'MockLichessUser'}, // Player is black
        'state': {'moves': '', 'status': 'started'}, // White's turn (opponent)
      };
      streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
      await tester.pump();
      await tester.pumpAndSettle();

      final squareE2 = find.text('E2');
      await tester.ensureVisible(squareE2);
      await tester.tap(squareE2);
      await tester.pumpAndSettle();

      final chessBoard = tester.widget<ChessBoard>(find.byType(ChessBoard));
      expect(chessBoard.selectedSquare, isNull);
      expect(chessBoard.readOnly, isTrue);
    });

    testWidgets(
      'LiveGameScreen - Illegal move: Rejected client-side with no API call',
      (WidgetTester tester) async {
        final service = LichessService.instance;
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
          'lichess_username': 'MockLichessUser',
        });
        await service.init();

        final streamController = StreamController<List<int>>();
        final mockStreamResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final mockStreamReq = MockStreamRequest(mockStreamResp);

        final challengeResp = MockChallengeResponse('{"ok": true}');
        final challengeReq = MockChallengeRequest(challengeResp);

        final mockClient = MockCombinedHttpClient(
          postRequest: challengeReq,
          getRequest: mockStreamReq,
        );
        service.clientFactory = () => mockClient;

        await tester.pumpWidget(
          const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
        );

        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {'moves': '', 'status': 'started'},
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pump();
        await tester.pumpAndSettle();

        final squareE2 = find.text('E2');
        await tester.ensureVisible(squareE2);
        await tester.tap(squareE2);
        await tester.pumpAndSettle();

        // Tap an illegal square e.g. H4
        final squareH4 = find.text('H4');
        await tester.ensureVisible(squareH4);
        await tester.tap(squareH4);
        await tester.pumpAndSettle();

        // Verify no POST requests were sent to the move endpoint
        final moveRequests = mockClient.requestedUrls.where(
          (url) => url.contains('/move/'),
        );
        expect(moveRequests, isEmpty);

        final chessBoard = tester.widget<ChessBoard>(find.byType(ChessBoard));
        expect(chessBoard.selectedSquare, isNull);
      },
    );

    testWidgets(
      'LiveGameScreen - Legal move: Sends correct UCI move to Lichess API',
      (WidgetTester tester) async {
        final service = LichessService.instance;
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
          'lichess_username': 'MockLichessUser',
        });
        await service.init();

        final streamController = StreamController<List<int>>();
        final mockStreamResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final mockStreamReq = MockStreamRequest(mockStreamResp);

        final challengeResp = MockChallengeResponse('{"ok": true}');
        final challengeReq = MockChallengeRequest(challengeResp);

        final mockClient = MockCombinedHttpClient(
          postRequest: challengeReq,
          getRequest: mockStreamReq,
        );
        service.clientFactory = () => mockClient;

        await tester.pumpWidget(
          const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
        );

        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {'moves': '', 'status': 'started'},
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pump();
        await tester.pumpAndSettle();

        final squareE2 = find.text('E2');
        await tester.ensureVisible(squareE2);
        await tester.tap(squareE2);
        await tester.pumpAndSettle();

        final squareE4 = find.text('E4');
        await tester.ensureVisible(squareE4);
        await tester.tap(squareE4);
        await tester.pumpAndSettle();

        final moveRequests = mockClient.requestedUrls.where(
          (url) => url.contains('/move/e2e4'),
        );
        expect(moveRequests, hasLength(1));
      },
    );

    testWidgets(
      'LiveGameScreen - Promotion: Opens existing dialog and appends suffix',
      (WidgetTester tester) async {
        final service = LichessService.instance;
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
          'lichess_username': 'MockLichessUser',
        });
        await service.init();

        final streamController = StreamController<List<int>>();
        final mockStreamResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final mockStreamReq = MockStreamRequest(mockStreamResp);

        final challengeResp = MockChallengeResponse('{"ok": true}');
        final challengeReq = MockChallengeRequest(challengeResp);

        final mockClient = MockCombinedHttpClient(
          postRequest: challengeReq,
          getRequest: mockStreamReq,
        );
        service.clientFactory = () => mockClient;

        await tester.pumpWidget(
          const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
        );

        // White pawn at b7 ready to promote to b8
        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {
            'moves': 'a2a4 b7b5 a4b5 a7a5 b5b6 a5a4 b6b7 a4a3',
            'status': 'started',
          },
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pump();
        await tester.pumpAndSettle();

        // Tap B7
        final squareB7 = find.text('B7');
        await tester.ensureVisible(squareB7);
        await tester.tap(squareB7);
        await tester.pumpAndSettle();

        // Tap A8 (promotion capture)
        final squareA8 = find.text('A8');
        await tester.ensureVisible(squareA8);
        await tester.tap(squareA8);
        await tester.pump(); // Start promotion choice dialog rendering

        expect(find.text('Promote Pawn to:'), findsOneWidget);
        expect(find.text('Queen'), findsOneWidget);

        final queenBtn = find.widgetWithText(ElevatedButton, '♕');
        expect(queenBtn, findsOneWidget);
        await tester.tap(queenBtn);
        await tester.pumpAndSettle();

        final moveRequests = mockClient.requestedUrls.where(
          (url) => url.contains('/move/b7a8q'),
        );
        expect(moveRequests, hasLength(1));
      },
    );

    testWidgets(
      'LiveGameScreen - Server rejection: Reverts state and shows SnackBar',
      (WidgetTester tester) async {
        final service = LichessService.instance;
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
          'lichess_username': 'MockLichessUser',
        });
        await service.init();

        final streamController = StreamController<List<int>>();
        final mockStreamResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final mockStreamReq = MockStreamRequest(mockStreamResp);

        final challengeResp = MockChallengeResponse(
          '{"error": "Not your turn"}',
          statusCode: 400,
        );
        final challengeReq = MockChallengeRequest(challengeResp);

        final mockClient = MockCombinedHttpClient(
          postRequest: challengeReq,
          getRequest: mockStreamReq,
        );
        service.clientFactory = () => mockClient;

        await tester.pumpWidget(
          const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
        );

        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {'moves': '', 'status': 'started'},
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pump();
        await tester.pumpAndSettle();

        final squareE2 = find.text('E2');
        await tester.ensureVisible(squareE2);
        await tester.tap(squareE2);
        await tester.pumpAndSettle();

        final squareE4 = find.text('E4');
        await tester.ensureVisible(squareE4);
        await tester.tap(squareE4);
        await tester.pumpAndSettle();

        expect(find.text('Move rejected: Not your turn'), findsOneWidget);
      },
    );

    testWidgets(
      'LiveGameScreen - Clock: Displays correct MM:SS for White and Black',
      (WidgetTester tester) async {
        final service = LichessService.instance;
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
          'lichess_username': 'MockLichessUser',
        });
        await service.init();

        final streamController = StreamController<List<int>>();
        final mockResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final mockReq = MockStreamRequest(mockResp);
        final mockClient = MockStreamHttpClient(mockReq);
        service.clientFactory = () => mockClient;

        await tester.pumpWidget(
          const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
        );

        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {
            'moves': '',
            'status': 'started',
            'wtime': 180000, // 3 minutes -> 03:00
            'btime': 240000, // 4 minutes -> 04:00
          },
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pump();
        await tester.pumpAndSettle();

        final playerText = tester.widget<Text>(
          find.byKey(const ValueKey('player_clock')),
        );
        final opponentText = tester.widget<Text>(
          find.byKey(const ValueKey('opponent_clock')),
        );

        expect(playerText.data, '03:00');
        expect(opponentText.data, '04:00');
      },
    );

    testWidgets(
      'LiveGameScreen - Clock: Only active player clock ticks down over time',
      (WidgetTester tester) async {
        final service = LichessService.instance;
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
          'lichess_username': 'MockLichessUser',
        });
        await service.init();

        final streamController = StreamController<List<int>>();
        final mockResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final mockReq = MockStreamRequest(mockResp);
        final mockClient = MockStreamHttpClient(mockReq);
        service.clientFactory = () => mockClient;

        await tester.pumpWidget(
          const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
        );

        // White's turn initially (moves is empty, player is White)
        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {
            'moves': '',
            'status': 'started',
            'wtime': 180000, // 03:00
            'btime': 240000, // 04:00
          },
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pump();
        await tester.pumpAndSettle();

        // Verify start state
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('player_clock'))).data,
          '03:00',
        );
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('opponent_clock')))
              .data,
          '04:00',
        );

        // Simulate 1.5 seconds ticking (1500 ms)
        await tester.pump(const Duration(milliseconds: 1500));

        // Active player's clock (player) should have decremented from 180000 by 1500ms to 178500ms -> 02:59
        // Opponent's clock stays static at 04:00
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('player_clock'))).data,
          '02:59',
        );
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('opponent_clock')))
              .data,
          '04:00',
        );
      },
    );

    testWidgets('LiveGameScreen - Clock: Snap to server on new gameState event', (
      WidgetTester tester,
    ) async {
      final service = LichessService.instance;
      SharedPreferences.setMockInitialValues({
        'lichess_access_token': 'mock_token',
        'lichess_username': 'MockLichessUser',
      });
      await service.init();

      final streamController = StreamController<List<int>>();
      final mockResp = MockStreamResponse(
        streamController.stream.asBroadcastStream(),
      );
      final mockReq = MockStreamRequest(mockResp);
      final mockClient = MockStreamHttpClient(mockReq);
      service.clientFactory = () => mockClient;

      await tester.pumpWidget(
        const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
      );

      final gameFull = {
        'type': 'gameFull',
        'white': {'name': 'MockLichessUser'},
        'black': {'name': 'Stockfish AI'},
        'state': {
          'moves': '',
          'status': 'started',
          'wtime': 180000,
          'btime': 240000,
        },
      };
      streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Tick 2 seconds so local clock drifts down to 02:58
      await tester.pump(const Duration(seconds: 2));
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('player_clock'))).data,
        '02:58',
      );

      // Now push a fresh gameState update from server with wtime = 175000 -> 02:55
      final gameState = {
        'type': 'gameState',
        'moves': 'e2e4', // now Black's turn (opponent)
        'wtime': 175000,
        'btime': 240000,
        'status': 'started',
      };
      streamController.add(utf8.encode('${json.encode(gameState)}\n'));
      await tester.pump();
      await tester.pumpAndSettle();

      // The clock should snap to 02:55 and 04:00
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('player_clock'))).data,
        '02:55',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('opponent_clock'))).data,
        '04:00',
      );
    });

    testWidgets(
      'LiveGameScreen - Clock: Red alert below 30 seconds threshold',
      (WidgetTester tester) async {
        final service = LichessService.instance;
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
          'lichess_username': 'MockLichessUser',
        });
        await service.init();

        final streamController = StreamController<List<int>>();
        final mockResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final mockReq = MockStreamRequest(mockResp);
        final mockClient = MockStreamHttpClient(mockReq);
        service.clientFactory = () => mockClient;

        await tester.pumpWidget(
          const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
        );

        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {
            'moves': '',
            'status': 'started',
            'wtime': 31000, // 31 seconds -> normal color
            'btime': 20000, // 20 seconds -> low-time warning (red)
          },
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pump();
        await tester.pumpAndSettle();

        final playerText = tester.widget<Text>(
          find.byKey(const ValueKey('player_clock')),
        );
        final opponentText = tester.widget<Text>(
          find.byKey(const ValueKey('opponent_clock')),
        );

        // Assert player color is not red (e.g. check it is not Colors.red[700])
        expect(playerText.style?.color, isNot(Colors.red[700]));
        // Assert opponent color IS red
        expect(opponentText.style?.color, Colors.red[700]);
      },
    );

    testWidgets(
      'LiveGameScreen - Clock: Disconnection pauses ticking and renders Paused text',
      (WidgetTester tester) async {
        final service = LichessService.instance;
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
          'lichess_username': 'MockLichessUser',
        });
        await service.init();

        final streamController = StreamController<List<int>>();
        final mockResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final mockReq = MockStreamRequest(mockResp);
        final mockClient = MockStreamHttpClient(mockReq);
        service.clientFactory = () => mockClient;

        await tester.pumpWidget(
          const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
        );

        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {
            'moves': '',
            'status': 'started',
            'wtime': 180000,
            'btime': 240000,
          },
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pump();
        await tester.pumpAndSettle();

        // Trigger disconnection by closing the stream / adding error
        streamController.addError(Exception('Network timeout'));
        await tester.pump();
        await tester.pumpAndSettle();

        final playerText = tester.widget<Text>(
          find.byKey(const ValueKey('player_clock')),
        );
        final opponentText = tester.widget<Text>(
          find.byKey(const ValueKey('opponent_clock')),
        );

        expect(playerText.data, 'Paused');
        expect(opponentText.data, 'Paused');
        expect(playerText.style?.color, Colors.grey[500]);
      },
    );

    testWidgets(
      'LiveGameScreen - Actions: Resign calls API on confirmation, does not call on cancel',
      (WidgetTester tester) async {
        final service = LichessService.instance;
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
          'lichess_username': 'MockLichessUser',
        });
        await service.init();

        final streamController = StreamController<List<int>>();
        final mockStreamResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final mockStreamReq = MockStreamRequest(mockStreamResp);

        final postResp = MockChallengeResponse('{"ok": true}');
        final postReq = MockChallengeRequest(postResp);

        final mockClient = MockCombinedHttpClient(
          postRequest: postReq,
          getRequest: mockStreamReq,
        );
        service.clientFactory = () => mockClient;

        await tester.pumpWidget(
          const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
        );

        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {'moves': '', 'status': 'started'},
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pumpAndSettle();

        // Open Actions Menu
        await tester.tap(find.byKey(const ValueKey('game_actions_menu')));
        await tester.pumpAndSettle();

        // Tap Resign
        await tester.tap(find.byKey(const ValueKey('action_resign')));
        await tester.pumpAndSettle();

        // Verify confirmation dialog is shown
        expect(find.text('Resign Game?'), findsOneWidget);

        // Tap Cancel
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Assert no resign URL requested
        expect(
          mockClient.requestedUrls.where((url) => url.contains('/resign')),
          isEmpty,
        );

        // Open Actions Menu again
        await tester.tap(find.byKey(const ValueKey('game_actions_menu')));
        await tester.pumpAndSettle();

        // Tap Resign again
        await tester.tap(find.byKey(const ValueKey('action_resign')));
        await tester.pumpAndSettle();

        // Tap Confirm
        await tester.tap(find.text('Resign'));
        await tester.pumpAndSettle();

        // Assert resign API endpoint was called
        expect(
          mockClient.requestedUrls.where((url) => url.contains('/resign')),
          hasLength(1),
        );
      },
    );

    testWidgets(
      'LiveGameScreen - Actions: Abort visibility and execution based on move count',
      (WidgetTester tester) async {
        final service = LichessService.instance;
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
          'lichess_username': 'MockLichessUser',
        });
        await service.init();

        final streamController = StreamController<List<int>>();
        final mockStreamResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final mockStreamReq = MockStreamRequest(mockStreamResp);

        final postResp = MockChallengeResponse('{"ok": true}');
        final postReq = MockChallengeRequest(postResp);

        final mockClient = MockCombinedHttpClient(
          postRequest: postReq,
          getRequest: mockStreamReq,
        );
        service.clientFactory = () => mockClient;

        await tester.pumpWidget(
          const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
        );

        // 1. Move count = 0 (game not started yet) -> Abort should be visible
        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {'moves': '', 'status': 'started'},
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pumpAndSettle();

        // Open menu
        await tester.tap(find.byKey(const ValueKey('game_actions_menu')));
        await tester.pumpAndSettle();

        // Abort game should be visible
        expect(find.byKey(const ValueKey('action_abort')), findsOneWidget);

        // Tap Abort
        await tester.tap(find.byKey(const ValueKey('action_abort')));
        await tester.pumpAndSettle();

        // Confirm dialog and execute
        expect(find.text('Abort Game?'), findsOneWidget);
        await tester.tap(find.text('Abort'));
        await tester.pumpAndSettle();

        expect(
          mockClient.requestedUrls.where((url) => url.contains('/abort')),
          hasLength(1),
        );
      },
    );

    testWidgets(
      'LiveGameScreen - Actions: Abort is hidden when game is past abortable window',
      (WidgetTester tester) async {
        final service = LichessService.instance;
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
          'lichess_username': 'MockLichessUser',
        });
        await service.init();

        final streamController = StreamController<List<int>>();
        final mockStreamResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final mockStreamReq = MockStreamRequest(mockStreamResp);
        final mockClient = MockStreamHttpClient(mockStreamReq);
        service.clientFactory = () => mockClient;

        await tester.pumpWidget(
          const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
        );

        // 2. Move count >= 2 -> Abort should NOT be visible
        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {'moves': 'e2e4 e7e5', 'status': 'started'},
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('game_actions_menu')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('action_abort')), findsNothing);
      },
    );

    testWidgets(
      'LiveGameScreen - Actions: Draw offer calls correct API and switches on stream updates',
      (WidgetTester tester) async {
        final service = LichessService.instance;
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
          'lichess_username': 'MockLichessUser',
        });
        await service.init();

        final streamController = StreamController<List<int>>();
        final mockStreamResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final mockStreamReq = MockStreamRequest(mockStreamResp);

        final postResp = MockChallengeResponse('{"ok": true}');
        final postReq = MockChallengeRequest(postResp);

        final mockClient = MockCombinedHttpClient(
          postRequest: postReq,
          getRequest: mockStreamReq,
        );
        service.clientFactory = () => mockClient;

        await tester.pumpWidget(
          const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
        );

        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {'moves': 'e2e4 e7e5', 'status': 'started'},
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pumpAndSettle();

        // Open menu
        await tester.tap(find.byKey(const ValueKey('game_actions_menu')));
        await tester.pumpAndSettle();

        // Offer Draw should be visible
        expect(find.byKey(const ValueKey('action_offer_draw')), findsOneWidget);
        expect(find.byKey(const ValueKey('action_accept_draw')), findsNothing);
        expect(find.byKey(const ValueKey('action_decline_draw')), findsNothing);

        // Offer Draw
        await tester.tap(find.byKey(const ValueKey('action_offer_draw')));
        await tester.pumpAndSettle();

        // Assert draw/yes called
        expect(
          mockClient.requestedUrls.where((url) => url.contains('/draw/yes')),
          hasLength(1),
        );

        // Push opponent draw offer update in stream
        final gameState = {
          'type': 'gameState',
          'moves': 'e2e4 e7e5',
          'status': 'started',
          'wdraw': false,
          'bdraw': true,
        };
        streamController.add(utf8.encode('${json.encode(gameState)}\n'));
        await tester.pumpAndSettle();

        // Open actions menu again
        await tester.tap(find.byKey(const ValueKey('game_actions_menu')));
        await tester.pumpAndSettle();

        // Action offer should be hidden, accept/decline should be visible
        expect(find.byKey(const ValueKey('action_offer_draw')), findsNothing);
        expect(
          find.byKey(const ValueKey('action_accept_draw')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('action_decline_draw')),
          findsOneWidget,
        );
      },
    );

    testWidgets('LiveGameScreen - Actions: Undo control is absent entirely', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
      );
      expect(find.text('Undo'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Undo'), findsNothing);
      expect(find.byIcon(Icons.undo), findsNothing);
    });

    testWidgets(
      'LiveGameScreen - Actions: Server rejection of actions shows SnackBar error',
      (WidgetTester tester) async {
        final service = LichessService.instance;
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
          'lichess_username': 'MockLichessUser',
        });
        await service.init();

        final streamController = StreamController<List<int>>();
        final mockStreamResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final mockStreamReq = MockStreamRequest(mockStreamResp);

        // Respond with 400 error
        final postResp = MockChallengeResponse(
          '{"error": "Game cannot be aborted anymore"}',
          statusCode: 400,
        );
        final postReq = MockChallengeRequest(postResp);

        final mockClient = MockCombinedHttpClient(
          postRequest: postReq,
          getRequest: mockStreamReq,
        );
        service.clientFactory = () => mockClient;

        await tester.pumpWidget(
          const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
        );

        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {'moves': '', 'status': 'started'},
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pumpAndSettle();

        // Tap actions
        await tester.tap(find.byKey(const ValueKey('game_actions_menu')));
        await tester.pumpAndSettle();

        // Tap Abort
        await tester.tap(find.byKey(const ValueKey('action_abort')));
        await tester.pumpAndSettle();

        // Confirm Abort
        await tester.tap(find.text('Abort'));
        await tester.pumpAndSettle();

        // Verify SnackBar with the error is displayed
        expect(
          find.text('Failed to abort: Game cannot be aborted anymore'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'LiveGameScreen - Blindfold: Piece symbols are hidden when Blindfold ON and threshold met',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        SettingsService.instance.resetToDefaults();
        await SettingsService.instance.setBlindfoldMode(true);
        await SettingsService.instance.setBlindfoldDifficulty(
          BlindfoldDifficulty.medium,
        ); // 5 moves

        final service = LichessService.instance;
        final streamController = StreamController<List<int>>();
        final mockStreamResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final mockStreamReq = MockStreamRequest(mockStreamResp);
        final mockClient = MockStreamHttpClient(mockStreamReq);
        service.clientFactory = () => mockClient;

        await tester.pumpWidget(
          const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
        );

        // 5 moves played (moves list length = 5)
        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {'moves': 'e2e4 e7e5 g1f3 b8c6 f1b5', 'status': 'started'},
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pumpAndSettle();

        // Find any ChessSquare on the board (e.g. E4)
        final squareFinder = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == 'E4',
        );
        expect(squareFinder, findsOneWidget);
        final square = tester.widget<ChessSquare>(squareFinder);

        // Should be hidden
        expect(square.isPieceHidden, isTrue);
      },
    );

    testWidgets(
      'LiveGameScreen - Blindfold: Tapping hidden piece shows legal highlights',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        SettingsService.instance.resetToDefaults();
        await SettingsService.instance.setBlindfoldMode(true);
        await SettingsService.instance.setBlindfoldDifficulty(
          BlindfoldDifficulty.hard,
        ); // 0 moves threshold

        final service = LichessService.instance;
        final streamController = StreamController<List<int>>();
        final mockStreamResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final mockStreamReq = MockStreamRequest(mockStreamResp);
        final mockClient = MockStreamHttpClient(mockStreamReq);
        service.clientFactory = () => mockClient;

        await tester.pumpWidget(
          const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
        );

        // White perspective, White turn
        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {'moves': '', 'status': 'started'},
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pumpAndSettle();

        // Verify E2 pawn is hidden
        final e2Finder = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == 'E2',
        );
        expect(tester.widget<ChessSquare>(e2Finder).isPieceHidden, isTrue);

        // Tap E2
        await tester.ensureVisible(e2Finder);
        await tester.tap(e2Finder);
        await tester.pumpAndSettle();

        // Should show highlights on E3 and E4 (e.g. highlightedSquares should contain (5, 4) and (4, 4))
        final dynamic dynamicState = tester.state(find.byType(LiveGameScreen));
        expect(dynamicState.highlightedSquares, isNotEmpty);

        // Pump to clear the guess flash timers
        await tester.pump(const Duration(milliseconds: 500));
      },
    );

    testWidgets(
      'LiveGameScreen - Blindfold: Correct/incorrect guesses update score',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        SettingsService.instance.resetToDefaults();
        await SettingsService.instance.setBlindfoldMode(true);
        await SettingsService.instance.setBlindfoldDifficulty(
          BlindfoldDifficulty.hard,
        );

        final service = LichessService.instance;
        final streamController = StreamController<List<int>>();
        final mockStreamResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final mockStreamReq = MockStreamRequest(mockStreamResp);
        final mockClient = MockStreamHttpClient(mockStreamReq);
        service.clientFactory = () => mockClient;

        await tester.pumpWidget(
          const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
        );

        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {'moves': '', 'status': 'started'},
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pumpAndSettle();

        // Tap an empty square (e.g. E4) -> Incorrect guess (since E4 is empty)
        final e4Finder = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == 'E4',
        );
        await tester.ensureVisible(e4Finder);
        await tester.tap(e4Finder);
        await tester.pumpAndSettle();

        // Tap player's own piece (e.g. E2) -> Correct guess (E2 has a White pawn, player is White)
        final e2Finder = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == 'E2',
        );
        await tester.ensureVisible(e2Finder);
        await tester.tap(e2Finder);
        await tester.pumpAndSettle();

        // Score should show 1 / 2 (50%)
        final scoreTextFinder = find.byKey(const ValueKey('memory_score_text'));
        expect(scoreTextFinder, findsOneWidget);
        final scoreText = tester.widget<Text>(scoreTextFinder);
        expect(scoreText.data, contains('1 / 2 (50%)'));

        // Pump to clear the guess flash timers
        await tester.pump(const Duration(milliseconds: 500));
      },
    );

    testWidgets(
      'LiveGameScreen - Blindfold: Reveal button temporarily shows pieces and re-hides',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        SettingsService.instance.resetToDefaults();
        await SettingsService.instance.setBlindfoldMode(true);
        await SettingsService.instance.setBlindfoldDifficulty(
          BlindfoldDifficulty.hard,
        );

        final service = LichessService.instance;
        final streamController = StreamController<List<int>>();
        final mockStreamResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final mockStreamReq = MockStreamRequest(mockStreamResp);
        final mockClient = MockStreamHttpClient(mockStreamReq);
        service.clientFactory = () => mockClient;

        await tester.pumpWidget(
          const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
        );

        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {'moves': '', 'status': 'started'},
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pumpAndSettle();

        // Verify E2 is hidden
        final e2Finder = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == 'E2',
        );
        expect(tester.widget<ChessSquare>(e2Finder).isPieceHidden, isTrue);

        // Tap Reveal Pieces
        final revealBtnFinder = find.byKey(const ValueKey('reveal_button'));
        expect(revealBtnFinder, findsOneWidget);
        await tester.ensureVisible(revealBtnFinder);
        await tester.tap(revealBtnFinder);
        await tester.pump();

        // Verify E2 is now visible
        expect(tester.widget<ChessSquare>(e2Finder).isPieceHidden, isFalse);

        // Advance clock by 3 seconds
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        // Verify E2 is hidden again
        expect(tester.widget<ChessSquare>(e2Finder).isPieceHidden, isTrue);
      },
    );

    testWidgets(
      'LiveGameScreen - Pre-configured Blindfold Entry: starts with Blindfold Mode ON',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
          'lichess_username': 'MockLichessUser',
        });
        final service = LichessService.instance;
        await service.init();
        SettingsService.instance.resetToDefaults();

        final streamController = StreamController<List<int>>();
        final streamResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final streamReq = MockStreamRequest(streamResp);

        final challengeResp = MockChallengeResponse(
          '{"id": "testGameId", "url": "https://lichess.org/testGameId"}',
        );
        final challengeReq = MockChallengeRequest(challengeResp);

        final mockClient = MockCombinedHttpClient(
          postRequest: challengeReq,
          getRequest: streamReq,
        );
        service.clientFactory = () => mockClient;

        await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
        await tester.pumpAndSettle();

        final playBtn = find.byKey(const ValueKey('play_blindfold_bot_btn'));
        expect(playBtn, findsOneWidget);
        await tester.ensureVisible(playBtn);
        await tester.tap(playBtn);
        await tester.pumpAndSettle();

        // Dialog is open. Verify the switch is ON by default
        final switchFinder = find.byKey(
          const ValueKey('dialog_blindfold_switch'),
        );
        expect(switchFinder, findsOneWidget);
        final Switch switchWidget = tester.widget<Switch>(switchFinder);
        expect(switchWidget.value, isTrue);

        // Select Easy difficulty preset (10 moves threshold)
        final easyChip = find.byKey(const ValueKey('dialog_chip_easy'));
        expect(easyChip, findsOneWidget);
        await tester.ensureVisible(easyChip);
        await tester.tap(easyChip);
        await tester.pumpAndSettle();

        // Tap Start Game button inside ChallengeBotDialog
        final startBtn = find.descendant(
          of: find.byType(ChallengeBotDialog),
          matching: find.text('Start Game'),
        );
        await tester.ensureVisible(startBtn);
        await tester.tap(startBtn);
        await tester.pump();

        // Mock stream event
        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {'moves': '', 'status': 'started'},
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pumpAndSettle();

        // Verify we are on LiveGameScreen
        expect(find.byType(LiveGameScreen), findsOneWidget);

        // Verify that SettingsService shows blindfold mode is ON and difficulty is Easy
        expect(SettingsService.instance.isBlindfoldMode, isTrue);
        expect(
          SettingsService.instance.blindfoldDifficulty,
          BlindfoldDifficulty.easy,
        );

        // Under 10 moves threshold (move count = 0), E2 square is visible (not hidden)
        final e2Finder = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == 'E2',
        );
        expect(tester.widget<ChessSquare>(e2Finder).isPieceHidden, isFalse);
      },
    );

    testWidgets(
      'LiveGameScreen - Pre-configured Blindfold Entry: regular bot flow starts with Blindfold Mode OFF',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
          'lichess_username': 'MockLichessUser',
        });
        final service = LichessService.instance;
        await service.init();
        SettingsService.instance.resetToDefaults();

        final streamController = StreamController<List<int>>();
        final streamResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final streamReq = MockStreamRequest(streamResp);

        final challengeResp = MockChallengeResponse(
          '{"id": "testGameId", "url": "https://lichess.org/testGameId"}',
        );
        final challengeReq = MockChallengeRequest(challengeResp);

        final mockClient = MockCombinedHttpClient(
          postRequest: challengeReq,
          getRequest: streamReq,
        );
        service.clientFactory = () => mockClient;

        await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
        await tester.pumpAndSettle();

        final playBtn = find.text('Play Lichess Bot');
        expect(playBtn, findsOneWidget);
        await tester.ensureVisible(playBtn);
        await tester.tap(playBtn);
        await tester.pumpAndSettle();

        // Dialog is open. Verify the switch is OFF by default
        final switchFinder = find.byKey(
          const ValueKey('dialog_blindfold_switch'),
        );
        expect(switchFinder, findsOneWidget);
        final Switch switchWidget = tester.widget<Switch>(switchFinder);
        expect(switchWidget.value, isFalse);

        // Tap Start Game button
        final startBtn = find.descendant(
          of: find.byType(ChallengeBotDialog),
          matching: find.text('Start Game'),
        );
        await tester.ensureVisible(startBtn);
        await tester.tap(startBtn);
        await tester.pump();

        // Mock stream event
        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {'moves': '', 'status': 'started'},
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pumpAndSettle();

        // Verify we are on LiveGameScreen and Blindfold is OFF
        expect(find.byType(LiveGameScreen), findsOneWidget);
        expect(SettingsService.instance.isBlindfoldMode, isFalse);
      },
    );

    testWidgets(
      'LiveGameScreen - Pre-configured Blindfold Entry: Hard difficulty hides pieces immediately at move 0',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
          'lichess_username': 'MockLichessUser',
        });
        final service = LichessService.instance;
        await service.init();
        SettingsService.instance.resetToDefaults();

        final streamController = StreamController<List<int>>();
        final streamResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final streamReq = MockStreamRequest(streamResp);

        final challengeResp = MockChallengeResponse(
          '{"id": "testGameId", "url": "https://lichess.org/testGameId"}',
        );
        final challengeReq = MockChallengeRequest(challengeResp);

        final mockClient = MockCombinedHttpClient(
          postRequest: challengeReq,
          getRequest: streamReq,
        );
        service.clientFactory = () => mockClient;

        await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
        await tester.pumpAndSettle();

        final playBtn = find.byKey(const ValueKey('play_blindfold_bot_btn'));
        await tester.ensureVisible(playBtn);
        await tester.tap(playBtn);
        await tester.pumpAndSettle();

        // Select Hard difficulty preset (0 moves threshold)
        final hardChip = find.byKey(const ValueKey('dialog_chip_hard'));
        await tester.ensureVisible(hardChip);
        await tester.tap(hardChip);
        await tester.pumpAndSettle();

        // Tap Start Game button
        final startBtn = find.descendant(
          of: find.byType(ChallengeBotDialog),
          matching: find.text('Start Game'),
        );
        await tester.ensureVisible(startBtn);
        await tester.tap(startBtn);
        await tester.pump();

        // Mock stream event
        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {'moves': '', 'status': 'started'},
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pumpAndSettle();

        // Verify pieces are hidden immediately at move 0
        final e2Finder = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == 'E2',
        );
        expect(tester.widget<ChessSquare>(e2Finder).isPieceHidden, isTrue);
      },
    );

    testWidgets(
      'LiveGameScreen - Pre-configured Blindfold Entry: manually toggling Blindfold mid-game works',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'lichess_access_token': 'mock_token',
          'lichess_username': 'MockLichessUser',
        });
        final service = LichessService.instance;
        await service.init();
        SettingsService.instance.resetToDefaults();

        final streamController = StreamController<List<int>>();
        final streamResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final streamReq = MockStreamRequest(streamResp);

        final challengeResp = MockChallengeResponse(
          '{"id": "testGameId", "url": "https://lichess.org/testGameId"}',
        );
        final challengeReq = MockChallengeRequest(challengeResp);

        final mockClient = MockCombinedHttpClient(
          postRequest: challengeReq,
          getRequest: streamReq,
        );
        service.clientFactory = () => mockClient;

        await tester.pumpWidget(
          const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
        );

        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {'moves': '', 'status': 'started'},
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pumpAndSettle();

        // Toggle switch in LiveGameScreen
        final switchFinder = find.byKey(const ValueKey('blindfold_switch'));
        expect(switchFinder, findsOneWidget);
        await tester.ensureVisible(switchFinder);
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        expect(SettingsService.instance.isBlindfoldMode, isTrue);

        // Toggle it back OFF
        await tester.ensureVisible(switchFinder);
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        expect(SettingsService.instance.isBlindfoldMode, isFalse);
      },
    );

    testWidgets('LiveGameScreen - completed checkmate event records stats', (
      WidgetTester tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lichess_access_token', 'mock_token');
      await prefs.setString('lichess_username', 'MockLichessUser');
      final service = LichessService.instance;
      await service.init();
      await StatisticsService.instance.clearStats();

      final streamController = StreamController<List<int>>();
      final streamResp = MockStreamResponse(
        streamController.stream.asBroadcastStream(),
      );
      final streamReq = MockStreamRequest(streamResp);

      final challengeResp = MockChallengeResponse(
        '{"id": "testGameId", "url": "https://lichess.org/testGameId"}',
      );
      final challengeReq = MockChallengeRequest(challengeResp);

      final mockClient = MockCombinedHttpClient(
        postRequest: challengeReq,
        getRequest: streamReq,
      );
      service.clientFactory = () => mockClient;

      // Force blindfold mode ON and difficulty hard (so pieces hide at move 0)
      SettingsService.instance.setBlindfoldMode(true);
      SettingsService.instance.setBlindfoldDifficulty(BlindfoldDifficulty.hard);

      await tester.pumpWidget(
        const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
      );

      final gameFull = {
        'type': 'gameFull',
        'white': {'name': 'MockLichessUser'},
        'black': {'name': 'Stockfish AI'},
        'state': {'moves': '', 'status': 'started'},
      };
      streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
      await tester.pumpAndSettle();

      // Ensure stats are initially zero
      expect(StatisticsService.instance.totalGamesPlayed, 0);

      // Add a game terminal event via stream: checkmate won by white
      final gameState = {
        'type': 'gameState',
        'moves': 'e2e4 e7e5 d1h5 b8c6 f1c4 g7g6 h5f3 g8f6 f3b3',
        'status': 'mate',
        'winner': 'white',
      };
      streamController.add(utf8.encode('${json.encode(gameState)}\n'));
      await tester.pumpAndSettle();

      // Check statistics service values
      expect(StatisticsService.instance.totalGamesPlayed, 1);
      expect(StatisticsService.instance.onlineGamesPlayed, 1);
      expect(StatisticsService.instance.totalBlindfoldGamesPlayed, 1);
      expect(StatisticsService.instance.onlineBlindfoldGamesPlayed, 1);
      expect(StatisticsService.instance.whiteWins, 1);
      expect(StatisticsService.instance.blackWins, 0);

      await streamController.close();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('LiveGameScreen - aborted event is excluded from stats', (
      WidgetTester tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lichess_access_token', 'mock_token');
      await prefs.setString('lichess_username', 'MockLichessUser');
      final service = LichessService.instance;
      await service.init();
      await StatisticsService.instance.clearStats();

      final streamController = StreamController<List<int>>();
      final streamResp = MockStreamResponse(
        streamController.stream.asBroadcastStream(),
      );
      final streamReq = MockStreamRequest(streamResp);

      final challengeResp = MockChallengeResponse(
        '{"id": "testGameId", "url": "https://lichess.org/testGameId"}',
      );
      final challengeReq = MockChallengeRequest(challengeResp);

      final mockClient = MockCombinedHttpClient(
        postRequest: challengeReq,
        getRequest: streamReq,
      );
      service.clientFactory = () => mockClient;

      await tester.pumpWidget(
        const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
      );

      final gameFull = {
        'type': 'gameFull',
        'white': {'name': 'MockLichessUser'},
        'black': {'name': 'Stockfish AI'},
        'state': {'moves': '', 'status': 'started'},
      };
      streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
      await tester.pumpAndSettle();

      // Add aborted event
      final gameState = {
        'type': 'gameState',
        'moves': 'e2e4 e7e5',
        'status': 'aborted',
      };
      streamController.add(utf8.encode('${json.encode(gameState)}\n'));
      await tester.pumpAndSettle();

      // Statistics must remain unchanged
      expect(StatisticsService.instance.totalGamesPlayed, 0);
      expect(StatisticsService.instance.onlineGamesPlayed, 0);

      await streamController.close();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets(
      'LiveGameScreen - navigating away mid-game records stats as a loss',
      (WidgetTester tester) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lichess_access_token', 'mock_token');
        await prefs.setString('lichess_username', 'MockLichessUser');
        final service = LichessService.instance;
        await service.init();
        await StatisticsService.instance.clearStats();

        final streamController = StreamController<List<int>>();
        final streamResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final streamReq = MockStreamRequest(streamResp);

        final challengeResp = MockChallengeResponse(
          '{"id": "testGameId", "url": "https://lichess.org/testGameId"}',
        );
        final challengeReq = MockChallengeRequest(challengeResp);

        final mockClient = MockCombinedHttpClient(
          postRequest: challengeReq,
          getRequest: streamReq,
        );
        service.clientFactory = () => mockClient;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => const LiveGameScreen(gameId: 'game123'),
                      ),
                    );
                  },
                  child: const Text('Open Screen'),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Open Screen'));
        await tester.pump(const Duration(milliseconds: 500));

        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {'moves': '', 'status': 'started'},
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pumpAndSettle();

        // Exit screen (without game terminal status)
        await tester.tap(find.byType(BackButton));
        await tester.pump(const Duration(milliseconds: 500));

        // Statistics must reflect 1 game completed and recorded as a loss (white is player, so black wins)
        expect(StatisticsService.instance.totalGamesPlayed, 1);
        expect(StatisticsService.instance.onlineGamesPlayed, 1);
        expect(StatisticsService.instance.blackWins, 1);
        expect(StatisticsService.instance.whiteWins, 0);

        // Verify that the Lichess resignation endpoint was called
        expect(
          mockClient.requestedUrls.contains(
            'https://lichess.org/api/board/game/game123/resign',
          ),
          isTrue,
        );

        await streamController.close();
      },
    );

    testWidgets(
      'LiveGameScreen - completed online blindfold game counts for achievements',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() async {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          await tester.binding.setSurfaceSize(null);
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lichess_access_token', 'mock_token');
        await prefs.setString('lichess_username', 'MockLichessUser');
        final service = LichessService.instance;
        await service.init();
        await StatisticsService.instance.clearStats();

        final streamController = StreamController<List<int>>();
        final streamResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final streamReq = MockStreamRequest(streamResp);

        final challengeResp = MockChallengeResponse(
          '{"id": "testGameId", "url": "https://lichess.org/testGameId"}',
        );
        final challengeReq = MockChallengeRequest(challengeResp);

        final mockClient = MockCombinedHttpClient(
          postRequest: challengeReq,
          getRequest: streamReq,
        );
        service.clientFactory = () => mockClient;

        SettingsService.instance.setBlindfoldMode(true);
        SettingsService.instance.setBlindfoldDifficulty(
          BlindfoldDifficulty.hard,
        );

        await tester.pumpWidget(
          const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
        );

        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {'moves': '', 'status': 'started'},
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pumpAndSettle();

        // Tap E2 then E4 (perfect guess check)
        final e2Finder = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == 'E2',
        );
        await tester.ensureVisible(e2Finder);
        await tester.tap(e2Finder);
        await tester.pump();
        final e4Finder = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == 'E4',
        );
        await tester.ensureVisible(e4Finder);
        await tester.tap(e4Finder);
        await tester.pump();

        // Checkmate event won by white
        final gameState = {
          'type': 'gameState',
          'moves': 'e2e4 e7e5 d1h5 b8c6 f1c4 g7g6 h5f3 g8f6 f3b3',
          'status': 'mate',
          'winner': 'white',
        };
        streamController.add(utf8.encode('${json.encode(gameState)}\n'));
        await tester.pumpAndSettle();

        // Under our mock setup: total guesses = 1, correct = 1 -> 100% memory accuracy
        expect(StatisticsService.instance.blindfoldWins, 1);
        expect(StatisticsService.instance.highestMemoryScore, 100);

        // Render Statistics Screen and verify achievements are unlocked
        await tester.pumpWidget(const MaterialApp(home: StatsScreen()));
        await tester.pumpAndSettle();

        // Expect Mind's Eye and Perfectionist to display "Unlocked"
        expect(find.text("Mind's Eye"), findsOneWidget);
        expect(find.text("Perfectionist"), findsOneWidget);

        await streamController.close();
      },
    );

    testWidgets(
      'LiveGameScreen - local and online stats exist side-by-side without interference',
      (WidgetTester tester) async {
        await StatisticsService.instance.clearStats();

        // Simulate 1 local game win (non-blindfold)
        await StatisticsService.instance.recordGame(
          isDraw: false,
          winningColor: 'white',
          halfMoves: 20,
          isBlindfoldModeActive: false,
        );

        // Simulate 1 online game win (blindfold)
        await StatisticsService.instance.recordGame(
          isDraw: false,
          winningColor: 'black',
          halfMoves: 16,
          isBlindfoldModeActive: true,
          memoryScorePercentage: 80,
          isOnline: true,
        );

        expect(StatisticsService.instance.totalGamesPlayed, 2);
        expect(StatisticsService.instance.onlineGamesPlayed, 1);
        expect(StatisticsService.instance.totalBlindfoldGamesPlayed, 1);
        expect(StatisticsService.instance.onlineBlindfoldGamesPlayed, 1);

        // Render stats screen
        await tester.pumpWidget(const MaterialApp(home: StatsScreen()));
        await tester.pumpAndSettle();

        // Verify the combined stats and specific online stats render correctly
        expect(find.text('2'), findsOneWidget); // Total games completed
        expect(
          find.text('1'),
          findsNWidgets(5),
        ); // Online games, online blindfold, white wins, black wins, total blindfold games
      },
    );

    testWidgets(
      'LiveGameScreen - AppLifecycleState.resumed triggers a stream re-subscription attempt',
      (WidgetTester tester) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lichess_access_token', 'mock_token');
        await prefs.setString('lichess_username', 'MockLichessUser');
        final service = LichessService.instance;
        await service.init();

        final streamController = StreamController<List<int>>();
        final streamResp = MockStreamResponse(
          streamController.stream.asBroadcastStream(),
        );
        final streamReq = MockStreamRequest(streamResp);

        final postResp = MockChallengeResponse('{}');
        final postReq = MockChallengeRequest(postResp);

        int connectionCount = 0;
        final mockClient = MockCombinedHttpClient(
          postRequest: postReq,
          getRequest: streamReq,
        );
        service.clientFactory = () {
          connectionCount++;
          return mockClient;
        };

        await tester.pumpWidget(
          const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
        );

        final gameFull = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {'moves': 'e2e4', 'status': 'started'},
        };
        streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
        await tester.pumpAndSettle();

        expect(connectionCount, 1);

        // Background the app (pause) then resume it
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();

        // Verify a new connection was initiated on resume
        expect(connectionCount, 2);

        await streamController.close();
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1600));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'LiveGameScreen - after reconnection, the displayed clock/board state reflects the mocked current server state',
      (WidgetTester tester) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lichess_access_token', 'mock_token');
        await prefs.setString('lichess_username', 'MockLichessUser');
        final service = LichessService.instance;
        await service.init();

        final streamController1 = StreamController<List<int>>();
        final streamResp1 = MockStreamResponse(
          streamController1.stream.asBroadcastStream(),
        );
        final streamReq1 = MockStreamRequest(streamResp1);

        final streamController2 = StreamController<List<int>>();
        final streamResp2 = MockStreamResponse(
          streamController2.stream.asBroadcastStream(),
        );
        final streamReq2 = MockStreamRequest(streamResp2);

        final postResp = MockChallengeResponse('{}');
        final postReq = MockChallengeRequest(postResp);

        int connectionCount = 0;
        service.clientFactory = () {
          connectionCount++;
          if (connectionCount == 1) {
            return MockCombinedHttpClient(
              postRequest: postReq,
              getRequest: streamReq1,
            );
          } else {
            return MockCombinedHttpClient(
              postRequest: postReq,
              getRequest: streamReq2,
            );
          }
        };

        await tester.pumpWidget(
          const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
        );

        final gameFull1 = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {
            'moves': 'e2e4',
            'status': 'started',
            'wtime': 180000,
            'btime': 180000,
          },
        };
        streamController1.add(utf8.encode('${json.encode(gameFull1)}\n'));
        await tester.pumpAndSettle();

        expect(find.text('Moves Played: 1'), findsOneWidget);

        // Background and resume
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();

        // Feed updated state to the new stream
        final gameFull2 = {
          'type': 'gameFull',
          'white': {'name': 'MockLichessUser'},
          'black': {'name': 'Stockfish AI'},
          'state': {
            'moves': 'e2e4 e7e5 g1f3',
            'status': 'started',
            'wtime': 175000,
            'btime': 160000,
          },
        };
        streamController2.add(utf8.encode('${json.encode(gameFull2)}\n'));
        await tester.pumpAndSettle();

        // Verify that the UI updated to reflect the new server state
        expect(find.text('Moves Played: 3'), findsOneWidget);
        // White clock should show 02:55, black clock should show 02:40
        expect(find.text('02:55'), findsOneWidget);
        expect(find.text('02:40'), findsOneWidget);

        await streamController1.close();
        await streamController2.close();
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1600));
        await tester.pumpAndSettle();
      },
    );
  });
}

class MockGamesListResponse implements HttpClientResponse {
  final String responseBody;
  @override
  final int statusCode;

  MockGamesListResponse(this.responseBody, {this.statusCode = 200});

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) {
    final bytes = utf8.encode(responseBody);
    return Stream<List<int>>.fromIterable([bytes]).transform(streamTransformer);
  }

  @override
  void noSuchMethod(Invocation invocation) {}
}

class MockCustomHttpClient implements HttpClient {
  final HttpClientRequest request;
  MockCustomHttpClient(this.request);

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => request;

  @override
  void noSuchMethod(Invocation invocation) {}
}

class MockCustomRequest implements HttpClientRequest {
  final HttpClientResponse response;
  MockCustomRequest(this.response);

  @override
  final HttpHeaders headers = MockHttpHeaders();

  @override
  void write(Object? obj) {}

  @override
  Future<HttpClientResponse> close() async => response;

  @override
  void noSuchMethod(Invocation invocation) {}
}

class MockTrackingClient implements HttpClient {
  final List<String> requestedUrls;
  MockTrackingClient(this.requestedUrls);

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requestedUrls.add(url.toString());
    return MockTrackingRequest(url.toString(), requestedUrls);
  }

  @override
  void noSuchMethod(Invocation invocation) {}
}

class MockTrackingRequest implements HttpClientRequest {
  final String url;
  final List<String> requestedUrls;

  MockTrackingRequest(this.url, this.requestedUrls);

  @override
  final HttpHeaders headers = MockHttpHeaders();

  @override
  void write(Object? obj) {}

  @override
  Future<HttpClientResponse> close() async {
    return MockTrackingResponse(url);
  }

  @override
  void noSuchMethod(Invocation invocation) {}
}

class MockTrackingResponse implements HttpClientResponse {
  final String url;
  MockTrackingResponse(this.url);

  @override
  int get statusCode => 200;

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) {
    String responseBody = '';
    if (url.contains('/api/games/user/')) {
      responseBody =
          '{"id":"game123","createdAt":1609459200000,"players":{"white":{"user":{"name":"MockLichessUser"}},"black":{"user":{"name":"OpponentPlayer"}}},"winner":"white","status":"mate"}\n'
          '{"id":"game456","createdAt":1609462800000,"players":{"white":{"user":{"name":"Opponent2"}},"black":{"user":{"name":"MockLichessUser"}}},"winner":"black","status":"resign"}';
    } else if (url.contains('/game/export/game123.pgn')) {
      responseBody =
          '[Event "Rated Blitz game"]\n[Site "https://lichess.org/"]\n[Date "2023.01.01"]\n[White "Player1"]\n[Black "Player2"]\n[Result "1-0"]\n\n1. e4 { [%eval 0.15] [%clk 0:03:00] } e5 { [%clk 0:03:00] } 2. Nf3 { [%eval 0.25] [%clk 0:02:58] } 1-0';
    }
    final bytes = utf8.encode(responseBody);
    final stream = Stream<List<int>>.fromFuture(
      Future.delayed(const Duration(milliseconds: 10), () => bytes),
    );
    return stream.transform(streamTransformer);
  }

  @override
  void noSuchMethod(Invocation invocation) {}
}

class MockChallengeResponse implements HttpClientResponse {
  @override
  final int statusCode;
  final String responseBody;
  MockChallengeResponse(this.responseBody, {this.statusCode = 200});

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) {
    final bytes = utf8.encode(responseBody);
    return Stream<List<int>>.fromIterable([bytes]).transform(streamTransformer);
  }

  @override
  void noSuchMethod(Invocation invocation) {}
}

class MockChallengeRequest implements HttpClientRequest {
  final HttpClientResponse response;
  final List<String> writtenBodies = [];

  MockChallengeRequest(this.response);

  @override
  final HttpHeaders headers = MockHttpHeaders();

  @override
  void write(Object? obj) {
    if (obj != null) {
      writtenBodies.add(obj.toString());
    }
  }

  @override
  Future<HttpClientResponse> close() async => response;

  @override
  void noSuchMethod(Invocation invocation) {}
}

class MockChallengeHttpClient implements HttpClient {
  final MockChallengeRequest request;
  final List<String> requestedUrls = [];

  MockChallengeHttpClient(this.request);

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    requestedUrls.add(url.toString());
    return request;
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requestedUrls.add(url.toString());
    return request;
  }

  @override
  void noSuchMethod(Invocation invocation) {}
}

class MockStreamResponse implements HttpClientResponse {
  final Stream<List<int>> stream;
  final VoidCallback? onCancel;

  MockStreamResponse(this.stream, {this.onCancel});

  @override
  int get statusCode => 200;

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) {
    final controller = StreamController<List<int>>();
    StreamSubscription? sub;
    controller.onListen = () {
      sub = stream.listen(
        (data) {
          if (!controller.isClosed) controller.add(data);
        },
        onError: (e) {
          if (!controller.isClosed) controller.addError(e);
        },
        onDone: () {
          if (!controller.isClosed) controller.close();
        },
      );
    };
    controller.onCancel = () {
      sub?.cancel();
      onCancel?.call();
    };
    return controller.stream.transform(streamTransformer);
  }

  @override
  void noSuchMethod(Invocation invocation) {}
}

class MockStreamRequest implements HttpClientRequest {
  final HttpClientResponse response;
  MockStreamRequest(this.response);

  @override
  final HttpHeaders headers = MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => response;

  @override
  void noSuchMethod(Invocation invocation) {}
}

class MockStreamHttpClient implements HttpClient {
  final MockStreamRequest request;
  final List<String> requestedUrls = [];

  MockStreamHttpClient(this.request);

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requestedUrls.add(url.toString());
    return request;
  }

  @override
  void noSuchMethod(Invocation invocation) {}
}

class MockCombinedHttpClient implements HttpClient {
  final HttpClientRequest postRequest;
  final HttpClientRequest getRequest;
  final List<String> requestedUrls = [];

  MockCombinedHttpClient({required this.postRequest, required this.getRequest});

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    requestedUrls.add(url.toString());
    return postRequest;
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requestedUrls.add(url.toString());
    return getRequest;
  }

  @override
  void noSuchMethod(Invocation invocation) {}
}
