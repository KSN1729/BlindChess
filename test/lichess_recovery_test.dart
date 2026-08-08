import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blind_chess/services/lichess_service.dart';
import 'package:blind_chess/screens/live_game_screen.dart';
import 'package:blind_chess/screens/home_screen.dart';
import 'package:blind_chess/services/settings_service.dart';
import 'package:blind_chess/services/statistics_service.dart';
import 'package:flutter/material.dart';

class MockHttpHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  set contentType(ContentType? type) {}
  @override
  void noSuchMethod(Invocation invocation) {}
}

class MockChallengeResponse implements HttpClientResponse {
  final String body;
  @override
  final int statusCode;

  MockChallengeResponse(this.body, {this.statusCode = 200});

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) {
    final bytes = utf8.encode(body);
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Online Live Game Recovery & Resilience Tests', () {
    late StreamController<List<int>> streamController;
    late MockStreamResponse streamResp;
    late MockStreamRequest streamReq;
    late MockChallengeResponse challengeResp;
    late MockChallengeRequest challengeReq;
    late MockCombinedHttpClient mockClient;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'lichess_access_token': 'mock_token',
        'lichess_username': 'MockLichessUser',
      });
      SettingsService.instance.resetToDefaults();
      LichessService.instance.resetForTesting();
      await LichessService.instance.init();
      await StatisticsService.instance.clearStats();

      streamController = StreamController<List<int>>();
      streamResp = MockStreamResponse(streamController.stream.asBroadcastStream());
      streamReq = MockStreamRequest(streamResp);

      challengeResp = MockChallengeResponse('{"ok": true}');
      challengeReq = MockChallengeRequest(challengeResp);

      mockClient = MockCombinedHttpClient(
        postRequest: challengeReq,
        getRequest: streamReq,
      );
      LichessService.instance.clientFactory = () => mockClient;
    });

    tearDown(() async {
      await streamController.close();
    });

    testWidgets('Active game ID is saved on load and cleared on exit', (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('lichess_active_game_id');

      await tester.pumpWidget(
        const MaterialApp(home: LiveGameScreen(gameId: 'recovery123')),
      );

      final gameFull = {
        'type': 'gameFull',
        'white': {'name': 'MockLichessUser'},
        'black': {'name': 'OpponentPlayer'},
        'clock': {'limit': 300, 'increment': 5},
        'state': {'moves': '', 'status': 'started'},
      };
      streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
      await tester.pump(const Duration(milliseconds: 200));

      // Check that active game ID was saved to SharedPreferences
      expect(prefs.getString('lichess_active_game_id'), equals('recovery123'));

      // Simulate manual exit
      final dynamic state = tester.state(find.byType(LiveGameScreen));
      state.simulateManualExit();
      await tester.pump(const Duration(milliseconds: 200));

      expect(prefs.getString('lichess_active_game_id'), isNull);

      // Clean up to unmount cleanly
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('HomeScreen automatically restores active game on startup', (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lichess_active_game_id', 'restoreGame456');

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify that LiveGameScreen is automatically navigated to
      expect(find.byType(LiveGameScreen), findsOneWidget);

      // Clean up
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('AppLifecycle resume triggers automatic stream reconnection', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LiveGameScreen(gameId: 'lifecycle789')),
      );

      final gameFull = {
        'type': 'gameFull',
        'white': {'name': 'MockLichessUser'},
        'black': {'name': 'OpponentPlayer'},
        'clock': {'limit': 300, 'increment': 5},
        'state': {'moves': '', 'status': 'started'},
      };
      streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
      await tester.pump(const Duration(milliseconds: 200));

      // Trigger background lifecycle state transition
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(milliseconds: 200));

      // Trigger resume lifecycle state transition
      mockClient.requestedUrls.clear();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 1600));

      // Verify it tried to establish stream again
      expect(mockClient.requestedUrls.any((url) => url.contains('/board/game/stream/lifecycle789')), isTrue);

      // Clean up
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Connection banner displays correctly when reconnecting and transitions to connected', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LiveGameScreen(gameId: 'reconnectUX')),
      );

      final gameFull = {
        'type': 'gameFull',
        'white': {'name': 'MockLichessUser'},
        'black': {'name': 'OpponentPlayer'},
        'clock': {'limit': 300, 'increment': 5},
        'state': {'moves': '', 'status': 'started'},
      };
      streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
      await tester.pump(const Duration(milliseconds: 200));

      final dynamic state = tester.state(find.byType(LiveGameScreen));

      // Simulate connection lost by trigger stream error
      state.simulateStreamError(const SocketException('Lost connection'));
      await tester.pump(const Duration(seconds: 2));

      // Check reconnecting banner is visible
      expect(find.textContaining('Reconnecting to Lichess...'), findsOneWidget);

      // Reconnect stream successfully
      streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
      await tester.pump(const Duration(milliseconds: 200));

      // Reconnecting banner should be gone
      expect(find.textContaining('Reconnecting to Lichess...'), findsNothing);

      // Clean up
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Stale or out-of-order FEN state triggers automatic reconciliation replay', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LiveGameScreen(gameId: 'reconciliation')),
      );

      final gameFull = {
        'type': 'gameFull',
        'white': {'name': 'MockLichessUser'},
        'black': {'name': 'OpponentPlayer'},
        'clock': {'limit': 300, 'increment': 5},
        'state': {'moves': 'e2e4 e7e5', 'status': 'started'},
      };
      streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
      await tester.pump(const Duration(milliseconds: 200));

      final dynamic state = tester.state(find.byType(LiveGameScreen));
      expect(state.moveCount, equals(2));

      // Simulate a state mismatch event where server moves skip ahead
      final gameState = {
        'type': 'gameState',
        'moves': 'e2e4 e7e5 g1f3 b8c6 f1b5',
        'status': 'started',
      };
      streamController.add(utf8.encode('${json.encode(gameState)}\n'));
      await tester.pump(const Duration(milliseconds: 200));

      // Verify that local move list was reconciled to length 5
      expect(state.moveCount, equals(5));

      // Clean up
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Five failed reconnect attempts transitions to completely disconnected offline mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LiveGameScreen(gameId: 'fiveFails')),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final dynamic state = tester.state(find.byType(LiveGameScreen));

      // Simulate 6 sequential error cycles where each reconnect attempt fails
      for (int i = 0; i < 6; i++) {
        state.simulateStreamError(const SocketException('Failed connection'));
        final delay = state.reconnectDelaySec;
        await tester.pump(Duration(seconds: delay + 1));
      }

      // Verify state has transitioned to completely disconnected
      expect(state.onlineConnectionState, equals(OnlineConnectionState.disconnected));
      expect(find.textContaining('You are offline.'), findsOneWidget);

      // Clean up
      await tester.pumpWidget(const SizedBox());
    });
  });
}
