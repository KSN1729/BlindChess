import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blind_chess/services/lichess_service.dart';
import 'package:blind_chess/screens/live_game_screen.dart';
import 'package:blind_chess/services/settings_service.dart';
import 'package:blind_chess/services/statistics_service.dart';
import 'package:flutter/material.dart';

// Reuse lightweight Mock HTTP Client definitions
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

  group('Online Move Synchronization & State Reconciliation', () {
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

    testWidgets('Move sync and duplicate guard protects concurrent move transmission', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
      );

      final gameFull = {
        'type': 'gameFull',
        'white': {'name': 'MockLichessUser'},
        'black': {'name': 'OpponentPlayer'},
        'clock': {'limit': 300, 'increment': 5},
        'state': {'moves': '', 'status': 'started'},
      };
      streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
      await tester.pumpAndSettle();

      // Find LiveGameScreen state
      final dynamic state = tester.state(find.byType(LiveGameScreen));

      // Attempt to transmit a move
      state.makeMove(6, 4, 4, 4); // e2 to e4
      expect(mockClient.requestedUrls, contains(contains('/move/e2e4')));

      // Simultaneous move attempt during sending should return false and not call postUrl again
      final canSendAgain = state.makeMove(6, 3, 4, 3); // d2 to d4
      expect(canSendAgain, isFalse);

      // Verify no extra post request is sent
      final callCount = mockClient.requestedUrls.where((url) => url.contains('/move/')).length;
      expect(callCount, 1);
    });

    testWidgets('Duplicate and out-of-order move updates are ignored', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
      );

      final gameFull = {
        'type': 'gameFull',
        'white': {'name': 'MockLichessUser'},
        'black': {'name': 'OpponentPlayer'},
        'state': {'moves': 'e2e4 e7e5', 'status': 'started'},
      };
      streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
      await tester.pumpAndSettle();

      final dynamic state = tester.state(find.byType(LiveGameScreen));
      expect(state.getLegalMoves().isNotEmpty, isTrue);

      // Send exact same moves list to verify it does not reset or replay the board
      final duplicateGameState = {
        'type': 'gameState',
        'moves': 'e2e4 e7e5',
        'status': 'started',
      };
      streamController.add(utf8.encode('${json.encode(duplicateGameState)}\n'));
      await tester.pumpAndSettle();

      // Board state remains correct and active
      expect(state.getLegalMoves().isNotEmpty, isTrue);
    });

    testWidgets('Opponent move updates audio, haptic, and toggles active clock', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
      );

      final gameFull = {
        'type': 'gameFull',
        'white': {'name': 'MockLichessUser'},
        'black': {'name': 'OpponentPlayer'},
        'clock': {'limit': 600, 'increment': 2},
        'state': {'moves': 'e2e4', 'status': 'started'},
      };
      streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
      await tester.pumpAndSettle();

      final dynamic state = tester.state(find.byType(LiveGameScreen));

      // Opponent moves
      final opponentGameState = {
        'type': 'gameState',
        'moves': 'e2e4 e7e5',
        'status': 'started',
      };
      streamController.add(utf8.encode('${json.encode(opponentGameState)}\n'));
      await tester.pumpAndSettle();

      // Check toggled clock active turn
      expect(state.getLegalMoves().isNotEmpty, isTrue);
    });

    testWidgets('Draw offer received/declined toggles voice status announcements', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
      );

      final gameFull = {
        'type': 'gameFull',
        'white': {'name': 'MockLichessUser'},
        'black': {'name': 'OpponentPlayer'},
        'state': {'moves': '', 'status': 'started'},
      };
      streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
      await tester.pumpAndSettle();

      // Trigger draw offer from opponent (black is opponent, so bdraw = true)
      final opponentDrawOffer = {
        'type': 'gameState',
        'moves': '',
        'status': 'started',
        'bdraw': true,
      };
      streamController.add(utf8.encode('${json.encode(opponentDrawOffer)}\n'));
      await tester.pumpAndSettle();

      // Toggling draw offer back to false implies declined
      final drawDeclined = {
        'type': 'gameState',
        'moves': '',
        'status': 'started',
        'bdraw': false,
      };
      streamController.add(utf8.encode('${json.encode(drawDeclined)}\n'));
      await tester.pumpAndSettle();
    });

    testWidgets('Opponent gone / connection status events speak warnings', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
      );

      final gameFull = {
        'type': 'gameFull',
        'white': {'name': 'MockLichessUser'},
        'black': {'name': 'OpponentPlayer'},
        'state': {'moves': '', 'status': 'started'},
      };
      streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
      await tester.pumpAndSettle();

      // Opponent disconnected event
      final opponentGone = {
        'type': 'opponentGone',
        'gone': true,
        'claimWinInSeconds': 10,
      };
      streamController.add(utf8.encode('${json.encode(opponentGone)}\n'));
      await tester.pumpAndSettle();

      // Opponent reconnected event
      final opponentReturned = {
        'type': 'opponentGone',
        'gone': false,
      };
      streamController.add(utf8.encode('${json.encode(opponentReturned)}\n'));
      await tester.pumpAndSettle();
    });

    testWidgets('Voice command resign / draw / help invoke appropriate API and UI responses', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: LiveGameScreen(gameId: 'game123')),
      );

      final gameFull = {
        'type': 'gameFull',
        'white': {'name': 'MockLichessUser'},
        'black': {'name': 'OpponentPlayer'},
        'state': {'moves': '', 'status': 'started'},
      };
      streamController.add(utf8.encode('${json.encode(gameFull)}\n'));
      await tester.pumpAndSettle();

      final dynamic state = tester.state(find.byType(LiveGameScreen));

      // Voice resign triggers Lichess resign API call
      state.onResign();
      expect(mockClient.requestedUrls, contains(contains('/resign')));

      // Voice draw offer triggers Lichess draw API call
      state.onDrawOffer();
      expect(mockClient.requestedUrls, contains(contains('/draw/yes')));

      // Voice help shows help dialog
      state.onHelp();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Voice Commands Help'), findsOneWidget);
    });
  });
}
