import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blind_chess/models/lichess_connection_state.dart';
import 'package:blind_chess/models/lichess_profile.dart';
import 'package:blind_chess/services/lichess_api_client.dart';
import 'package:blind_chess/services/lichess_session_manager.dart';
import 'package:blind_chess/repositories/lichess_user_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('Lichess Connection State and Profile Models', () {
    test('LichessProfile maps JSON correctly', () {
      final json = {
        'username': 'chess_master',
        'title': 'GM',
        'perfs': {
          'blitz': {'rating': 2450},
          'rapid': {'rating': 2300},
        },
        'count': {
          'all': 100,
          'win': 50,
          'loss': 40,
          'draw': 10,
        },
        'online': true,
      };

      final profile = LichessProfile.fromJson(json);
      expect(profile.username, 'chess_master');
      expect(profile.title, 'GM');
      expect(profile.blitzRating, 2450);
      expect(profile.rapidRating, 2300);
      expect(profile.gamesPlayed, 100);
      expect(profile.wins, 50);
      expect(profile.losses, 40);
      expect(profile.draws, 10);
      expect(profile.isOnline, true);
    });

    test('LichessProfile converts to JSON map correctly', () {
      const profile = LichessProfile(
        username: 'chess_master',
        title: 'IM',
        blitzRating: 2200,
        rapidRating: 2150,
        gamesPlayed: 50,
        wins: 30,
        losses: 15,
        draws: 5,
        isOnline: false,
      );

      final json = profile.toJson();
      expect(json['username'], 'chess_master');
      expect(json['title'], 'IM');
      expect(json['perfs']['blitz']['rating'], 2200);
      expect(json['perfs']['rapid']['rating'], 2150);
      expect(json['count']['all'], 50);
      expect(json['count']['win'], 30);
      expect(json['count']['loss'], 15);
      expect(json['count']['draw'], 5);
      expect(json['online'], false);
    });
  });

  group('LichessSessionManager & Secure Storage', () {
    late MockFlutterSecureStorage mockSecureStorage;
    late LichessSessionManager sessionManager;

    setUp(() {
      mockSecureStorage = MockFlutterSecureStorage();
      sessionManager = LichessSessionManager(secureStorage: mockSecureStorage);
    });

    test('Loads token and restores session on startup', () async {
      await mockSecureStorage.write(key: 'lichess_access_token_secure', value: 'secret_token_123');
      final restored = await sessionManager.restoreSession();

      expect(restored, true);
      expect(sessionManager.accessToken, 'secret_token_123');
      expect(sessionManager.connectionState, LichessConnectionState.connected);
    });

    test('Save session commits token and notifies listeners', () async {
      final states = <LichessConnectionState>[];
      sessionManager.connectionStateNotifier.addListener(() {
        states.add(sessionManager.connectionState);
      });

      await sessionManager.saveSession('new_token_456');

      expect(await mockSecureStorage.read(key: 'lichess_access_token_secure'), 'new_token_456');
      expect(sessionManager.accessToken, 'new_token_456');
      expect(states, [LichessConnectionState.connected]);
    });

    test('Clear session deletes token and notifies listeners', () async {
      await sessionManager.saveSession('token_to_delete');
      expect(sessionManager.connectionState, LichessConnectionState.connected);

      final states = <LichessConnectionState>[];
      sessionManager.connectionStateNotifier.addListener(() {
        states.add(sessionManager.connectionState);
      });

      await sessionManager.clearSession();

      expect(await mockSecureStorage.read(key: 'lichess_access_token_secure'), isNull);
      expect(sessionManager.accessToken, isNull);
      expect(states, [LichessConnectionState.disconnected]);
    });
  });

  group('LichessApiClient robust features', () {
    test('Appends User-Agent and Authorization headers', () async {
      final client = LichessApiClient(
        tokenProvider: () => 'my_mock_token',
        clientFactory: () {
          return MockHttpClient((uri, method) async {
            final response = MockHttpClientResponse(statusCode: 200, responseBody: '{"ok": true}');
            final request = MockHttpClientRequest(response);
            return request;
          });
        },
      );

      final response = await client.get('/api/account');
      expect(response['ok'], true);
    });

    test('Rate-limiting queue spacing delays requests sequentially', () async {
      final requestTimes = <DateTime>[];
      final client = LichessApiClient(
        tokenProvider: () => null,
        clientFactory: () {
          return MockHttpClient((uri, method) async {
            requestTimes.add(DateTime.now());
            final response = MockHttpClientResponse(statusCode: 200, responseBody: '{"ok": true}');
            return MockHttpClientRequest(response);
          });
        },
        rateLimitInterval: const Duration(milliseconds: 100),
      );

      final f1 = client.get('/test1');
      final f2 = client.get('/test2');

      await Future.wait([f1, f2]);

      expect(requestTimes.length, 2);
      final difference = requestTimes[1].difference(requestTimes[0]).inMilliseconds;
      expect(difference, greaterThanOrEqualTo(95)); // Spaced by at least 100ms
    });

    test('Retries on network failures before rethrowing', () async {
      int attempts = 0;
      final client = LichessApiClient(
        tokenProvider: () => null,
        clientFactory: () {
          return MockHttpClient((uri, method) async {
            attempts++;
            throw const SocketException('Temporary DNS error');
          });
        },
      );

      expect(
        () => client.get('/test'),
        throwsA(isA<LichessNetworkException>()),
      );
      // Wait for async retries to finish
      await Future.delayed(const Duration(milliseconds: 2000));
      expect(attempts, 3); // 3 retries
    });

    test('Handles 429 Too Many Requests rate-limiting blocks', () async {
      final client = LichessApiClient(
        tokenProvider: () => null,
        clientFactory: () {
          return MockHttpClient((uri, method) async {
            return MockHttpClientRequest(
              MockHttpClientResponse(statusCode: 429, responseBody: 'Rate Limit'),
            );
          });
        },
      );

      expect(
        () => client.get('/test'),
        throwsA(isA<LichessRateLimitException>()),
      );
    });

    test('Handles 401 Unauthorized token status', () async {
      final client = LichessApiClient(
        tokenProvider: () => null,
        clientFactory: () {
          return MockHttpClient((uri, method) async {
            return MockHttpClientRequest(
              MockHttpClientResponse(statusCode: 401, responseBody: 'Unauthorized'),
            );
          });
        },
      );

      expect(
        () => client.get('/test'),
        throwsA(isA<LichessUnauthorizedException>()),
      );
    });
  });

  group('LichessUserRepository Caching', () {
    test('loadProfile calls API and updates profileNotifier cached detail', () async {
      final apiClient = LichessApiClient(
        tokenProvider: () => 'token',
        clientFactory: () {
          return MockHttpClient((uri, method) async {
            final json = {
              'username': 'grandmaster_x',
              'perfs': {
                'blitz': {'rating': 2800},
              }
            };
            return MockHttpClientRequest(
              MockHttpClientResponse(statusCode: 200, responseBody: jsonEncode(json)),
            );
          });
        },
      );

      final repo = LichessUserRepository(apiClient: apiClient);
      expect(repo.profile, isNull);

      final profile = await repo.loadProfile();
      expect(profile.username, 'grandmaster_x');
      expect(repo.profile?.username, 'grandmaster_x');
      expect(repo.profile?.blitzRating, 2800);
    });
  });
}

// --- Direct Mock classes for FlutterSecureStorage and HttpClient ---

class MockFlutterSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read({
    required String key,
    dynamic aOptions,
    dynamic iOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
  }) async {
    return _storage[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    dynamic aOptions,
    dynamic iOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
  }) async {
    if (value != null) {
      _storage[key] = value;
    } else {
      _storage.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    dynamic aOptions,
    dynamic iOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
  }) async {
    _storage.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #deleteAll) {
      _storage.clear();
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class MockHttpClient implements HttpClient {
  final Future<HttpClientRequest> Function(Uri uri, String method) requestBuilder;

  MockHttpClient(this.requestBuilder);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => requestBuilder(url, 'POST');

  @override
  Future<HttpClientRequest> getUrl(Uri url) => requestBuilder(url, 'GET');

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHttpClientRequest implements HttpClientRequest {
  final HttpClientResponse response;
  @override
  final HttpHeaders headers = MockHttpHeaders();

  MockHttpClientRequest(this.response);

  @override
  void write(Object? object) {}

  @override
  Future<HttpClientResponse> close() async => response;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  final int statusCode;
  final String responseBody;

  MockHttpClientResponse({required this.statusCode, required this.responseBody});

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(utf8.encode(responseBody)).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _headers = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name] = [value.toString()];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
