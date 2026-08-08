import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blind_chess/services/lichess_api_client.dart';
import 'package:blind_chess/services/lichess_service.dart';
import 'package:blind_chess/models/lichess_connection_state.dart';
import 'package:blind_chess/models/lichess_online_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LichessService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'lichess_access_token': 'mock_secret_token',
      'lichess_username': 'MockLichessUser',
    });
    service = LichessService.instance;
    await service.init();
  });

  tearDown(() {
    service.resetForTesting();
  });

  group('Lichess Online Models JSON Deserialization', () {
    test('LichessPlayer.fromJson parses fields correctly', () {
      final jsonMap = {
        'id': 'player123',
        'name': 'GrandmasterName',
        'rating': 2100,
        'title': 'GM',
      };
      final player = LichessPlayer.fromJson(jsonMap);
      expect(player.id, 'player123');
      expect(player.name, 'GrandmasterName');
      expect(player.rating, 2100);
      expect(player.title, 'GM');
    });

    test('LichessClock.fromJson parses fields correctly', () {
      final jsonMap = {
        'initial': 300,
        'increment': 5,
      };
      final clock = LichessClock.fromJson(jsonMap);
      expect(clock.initial, 300);
      expect(clock.increment, 5);
    });

    test('LichessChallenge.fromJson parses fields correctly', () {
      final jsonMap = {
        'id': 'chal123',
        'url': 'https://lichess.org/chal123',
        'status': 'created',
        'challenger': {'id': 'alice', 'name': 'Alice', 'rating': 1600},
        'destUser': {'id': 'bob', 'name': 'Bob', 'rating': 1700},
        'variant': {'key': 'standard', 'name': 'Standard'},
        'rated': true,
        'speed': 'blitz',
        'timeControl': {'limit': 180, 'increment': 2},
        'color': 'random',
      };
      final challenge = LichessChallenge.fromJson(jsonMap);
      expect(challenge.id, 'chal123');
      expect(challenge.url, 'https://lichess.org/chal123');
      expect(challenge.challengerName, 'Alice');
      expect(challenge.challengerRating, 1600);
      expect(challenge.destUserName, 'Bob');
      expect(challenge.destUserRating, 1700);
      expect(challenge.rated, true);
      expect(challenge.speed, 'blitz');
      expect(challenge.clockLimit, 180);
      expect(challenge.clockIncrement, 2);
      expect(challenge.color, 'random');
    });

    test('LichessActiveGame.fromJson parses fields correctly', () {
      final jsonMap = {
        'gameId': 'game123',
        'fullId': 'full123',
        'color': 'white',
        'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        'hasMoved': true,
        'isMyTurn': true,
        'lastMove': 'e2e4',
        'opponent': {'username': 'Stockfish', 'rating': 2500},
        'secondsLeft': 600,
        'source': 'api',
        'speed': 'rapid',
        'variant': {'key': 'standard'},
      };
      final game = LichessActiveGame.fromJson(jsonMap);
      expect(game.gameId, 'game123');
      expect(game.color, 'white');
      expect(game.fen, 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      expect(game.isMyTurn, true);
      expect(game.opponentName, 'Stockfish');
      expect(game.opponentRating, 2500);
      expect(game.secondsLeft, 600);
      expect(game.speed, 'rapid');
    });
  });

  group('LichessService Challenge & Playing REST APIs', () {
    test('createOpenChallenge post request format and response parsing', () async {
      final responseBody = {
        'challenge': {
          'id': 'open123',
          'url': 'https://lichess.org/open123',
          'status': 'created',
          'challenger': {'id': 'user1'},
          'variant': {'key': 'standard'},
          'rated': false,
          'speed': 'blitz',
          'timeControl': {'limit': 300, 'increment': 3},
          'color': 'random',
        }
      };

      final mockResp = MockHttpResponse(200, json.encode(responseBody));
      final mockReq = MockHttpRequest(mockResp);
      final mockClient = MockTestHttpClient(mockReq);
      service.clientFactory = () => mockClient;

      final challenge = await service.createOpenChallenge(
        clockLimit: 300,
        clockIncrement: 3,
        color: 'random',
        rated: false,
      );

      expect(challenge.id, 'open123');
      expect(challenge.url, 'https://lichess.org/open123');
      expect(challenge.rated, false);
      expect(challenge.clockLimit, 300);
      expect(challenge.clockIncrement, 3);
      expect(mockClient.requestedUrls.first, 'https://lichess.org/api/challenge/open');
      expect(mockReq.writtenBodies.first, 'clock.limit=300&clock.increment=3&color=random&rated=false&variant=standard');
    });

    test('createOpponentChallenge post request format and response parsing', () async {
      final responseBody = {
        'challenge': {
          'id': 'opp123',
          'url': 'https://lichess.org/opp123',
          'status': 'created',
          'challenger': {'id': 'user1'},
          'destUser': {'id': 'enemy1'},
          'variant': {'key': 'standard'},
          'rated': true,
          'speed': 'blitz',
          'timeControl': {'limit': 180, 'increment': 0},
          'color': 'white',
        }
      };

      final mockResp = MockHttpResponse(200, json.encode(responseBody));
      final mockReq = MockHttpRequest(mockResp);
      final mockClient = MockTestHttpClient(mockReq);
      service.clientFactory = () => mockClient;

      final challenge = await service.createOpponentChallenge(
        opponent: 'enemy1',
        clockLimit: 180,
        clockIncrement: 0,
        color: 'white',
        rated: true,
      );

      expect(challenge.id, 'opp123');
      expect(challenge.destUserName, 'enemy1');
      expect(challenge.rated, true);
      expect(mockClient.requestedUrls.first, 'https://lichess.org/api/challenge/enemy1');
    });

    test('fetchChallenges parses incoming and outgoing lists', () async {
      final responseBody = {
        'in': [
          {
            'id': 'in1',
            'challenger': {'id': 'alice'},
            'rated': false,
            'speed': 'blitz',
            'timeControl': {'limit': 180, 'increment': 2},
          }
        ],
        'out': [
          {
            'id': 'out1',
            'challenger': {'id': 'user1'},
            'destUser': {'id': 'bob'},
            'rated': true,
            'speed': 'bullet',
            'timeControl': {'limit': 60, 'increment': 0},
          }
        ]
      };

      final mockResp = MockHttpResponse(200, json.encode(responseBody));
      final mockReq = MockHttpRequest(mockResp);
      final mockClient = MockTestHttpClient(mockReq);
      service.clientFactory = () => mockClient;

      final map = await service.fetchChallenges();
      expect(map['in']!.length, 1);
      expect(map['out']!.length, 1);
      expect(map['in']!.first.id, 'in1');
      expect(map['out']!.first.id, 'out1');
      expect(mockClient.requestedUrls.first, 'https://lichess.org/api/challenge');
    });

    test('acceptChallenge calls correct POST url', () async {
      final mockResp = MockHttpResponse(200, '{}');
      final mockReq = MockHttpRequest(mockResp);
      final mockClient = MockTestHttpClient(mockReq);
      service.clientFactory = () => mockClient;

      await service.acceptChallenge('chal999');
      expect(mockClient.requestedUrls.first, 'https://lichess.org/api/challenge/chal999/accept');
    });

    test('declineChallenge calls correct POST url and payload', () async {
      final mockResp = MockHttpResponse(200, '{}');
      final mockReq = MockHttpRequest(mockResp);
      final mockClient = MockTestHttpClient(mockReq);
      service.clientFactory = () => mockClient;

      await service.declineChallenge('chal999', reason: 'later');
      expect(mockClient.requestedUrls.first, 'https://lichess.org/api/challenge/chal999/decline');
      expect(mockReq.writtenBodies.first, 'reason=later');
    });

    test('cancelChallenge calls correct POST url', () async {
      final mockResp = MockHttpResponse(200, '{}');
      final mockReq = MockHttpRequest(mockResp);
      final mockClient = MockTestHttpClient(mockReq);
      service.clientFactory = () => mockClient;

      await service.cancelChallenge('chal999');
      expect(mockClient.requestedUrls.first, 'https://lichess.org/api/challenge/chal999/cancel');
    });

    test('fetchActiveGames parses playing games correctly', () async {
      final responseBody = {
        'nowPlaying': [
          {
            'gameId': 'play1',
            'fullId': 'fullplay1',
            'color': 'black',
            'fen': 'fen_string',
            'hasMoved': true,
            'isMyTurn': false,
            'opponent': {'username': 'grandmaster'},
            'secondsLeft': 120,
            'source': 'api',
            'speed': 'rapid',
          }
        ]
      };

      final mockResp = MockHttpResponse(200, json.encode(responseBody));
      final mockReq = MockHttpRequest(mockResp);
      final mockClient = MockTestHttpClient(mockReq);
      service.clientFactory = () => mockClient;

      final list = await service.fetchActiveGames();
      expect(list.length, 1);
      expect(list.first.gameId, 'play1');
      expect(list.first.opponentName, 'grandmaster');
      expect(list.first.isMyTurn, false);
      expect(mockClient.requestedUrls.first, 'https://lichess.org/api/account/playing');
    });
  });

  group('Lichess Event Stream Connection & Heartbeats', () {
    test('event stream correctly processes event maps and notifies', () async {
      final streamController = StreamController<List<int>>();
      final mockResp = MockTestStreamResponse(streamController.stream);
      final mockReq = MockHttpRequest(mockResp);
      final mockClient = MockTestHttpClient(mockReq);
      service.clientFactory = () => mockClient;

      final eventsStream = service.streamEvents();
      final eventsReceived = <LichessEvent>[];

      final sub = eventsStream.listen((event) {
        eventsReceived.add(event);
      });

      // Let event stream connect
      await Future.delayed(const Duration(milliseconds: 10));

      final firstEvent = {
        'type': 'challenge',
        'challenge': {
          'id': 'eventchal1',
          'status': 'created',
          'challenger': {'id': 'alice'},
          'variant': {'key': 'standard'},
          'rated': false,
          'speed': 'blitz',
          'timeControl': {'limit': 180, 'increment': 2},
          'color': 'random',
        }
      };

      final secondEvent = {
        'type': 'gameStart',
        'game': {'id': 'eventgame1'}
      };

      streamController.add(utf8.encode('${json.encode(firstEvent)}\n'));
      streamController.add(utf8.encode('${json.encode(secondEvent)}\n'));

      await Future.delayed(const Duration(milliseconds: 10));

      expect(eventsReceived.length, 2);
      expect(eventsReceived[0].type, 'challenge');
      expect(eventsReceived[0].challenge!.id, 'eventchal1');
      expect(eventsReceived[1].type, 'gameStart');
      expect(eventsReceived[1].gameId, 'eventgame1');

      await sub.cancel();
      await streamController.close();
    });

    test('event stream reconnects automatically on stream completion', () async {
      final streamController1 = StreamController<List<int>>();
      final streamController2 = StreamController<List<int>>();
      
      int connectionAttempts = 0;
      final mockClient = MockCustomTestHttpClient((uri) {
        connectionAttempts++;
        if (connectionAttempts == 1) {
          final mockResp = MockTestStreamResponse(streamController1.stream);
          return MockHttpRequest(mockResp);
        } else {
          final mockResp = MockTestStreamResponse(streamController2.stream);
          return MockHttpRequest(mockResp);
        }
      });

      service.clientFactory = () => mockClient;

      final eventsStream = service.streamEvents();
      final eventsReceived = <LichessEvent>[];

      final sub = eventsStream.listen((event) {
        eventsReceived.add(event);
      });

      await Future.delayed(const Duration(milliseconds: 10));
      expect(connectionAttempts, 1);

      // Close first stream to trigger reconnect
      await streamController1.close();
      await Future.delayed(const Duration(milliseconds: 1100)); // waits reconnect delay

      expect(connectionAttempts, 2);

      final reconnectEvent = {
        'type': 'gameStart',
        'game': {'id': 'reconnectgame1'}
      };
      streamController2.add(utf8.encode('${json.encode(reconnectEvent)}\n'));
      await Future.delayed(const Duration(milliseconds: 10));

      expect(eventsReceived.length, 1);
      expect(eventsReceived[0].gameId, 'reconnectgame1');

      await sub.cancel();
      await streamController2.close();
    });

    test('LichessUnauthorizedException in stream transitions state and throws error', () async {
      final mockResp = MockTestStreamResponse(
        const Stream<List<int>>.empty(),
        customStatusCode: 401,
      );
      final mockReq = MockHttpRequest(mockResp);
      final mockClient = MockTestHttpClient(mockReq);
      service.clientFactory = () => mockClient;

      final eventsStream = service.streamEvents();
      final completer = Completer<dynamic>();

      final sub = eventsStream.listen(
        (_) {},
        onError: (e) {
          if (!completer.isCompleted) {
            completer.complete(e);
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        },
      );

      final error = await completer.future.timeout(const Duration(seconds: 5));

      expect(service.sessionManager.connectionState, LichessConnectionState.authenticationExpired);
      expect(error, isA<LichessUnauthorizedException>());

      await sub.cancel();
    });
  });
}

// Custom Mock Classes for Isolated HTTP Testing
class MockHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _headers = {};

  @override
  List<String>? operator [](String name) => _headers[name.toLowerCase()];

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers.putIfAbsent(name.toLowerCase(), () => []).add(value.toString());
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name.toLowerCase()] = [value.toString()];
  }

  @override
  void noSuchMethod(Invocation invocation) {}
}

class MockHttpResponse implements HttpClientResponse {
  @override
  final int statusCode;
  final String body;

  MockHttpResponse(this.statusCode, this.body);

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) {
    final bytes = utf8.encode(body);
    final controller = StreamController<List<int>>();
    controller.add(bytes);
    controller.close();
    return controller.stream.transform(streamTransformer);
  }

  @override
  void noSuchMethod(Invocation invocation) {}
}

class MockTestStreamResponse implements HttpClientResponse {
  final Stream<List<int>> stream;
  final int customStatusCode;

  MockTestStreamResponse(this.stream, {this.customStatusCode = 200});

  @override
  int get statusCode => customStatusCode;

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) {
    return stream.transform(streamTransformer);
  }

  @override
  void noSuchMethod(Invocation invocation) {}
}

class MockHttpRequest implements HttpClientRequest {
  final HttpClientResponse response;
  final List<String> writtenBodies = [];

  MockHttpRequest(this.response);

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

class MockTestHttpClient implements HttpClient {
  final MockHttpRequest request;
  final List<String> requestedUrls = [];

  MockTestHttpClient(this.request);

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

class MockCustomTestHttpClient implements HttpClient {
  final HttpClientRequest Function(Uri uri) handler;

  MockCustomTestHttpClient(this.handler);

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return handler(url);
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    return handler(url);
  }

  @override
  void noSuchMethod(Invocation invocation) {}
}
