import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/lichess_connection_state.dart';

/// In-memory mock storage used as a fallback to avoid MissingPluginException in tests.
class InMemorySecureStorage implements FlutterSecureStorage {
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

/// Service managing the lifecycle of authentication tokens and active connection state.
class LichessSessionManager {
  static const String _keyToken = 'lichess_access_token_secure';

  /// Instance of FlutterSecureStorage to read/write encrypted tokens (overridable in testing).
  FlutterSecureStorage secureStorage;

  final ValueNotifier<LichessConnectionState> connectionStateNotifier =
      ValueNotifier<LichessConnectionState>(LichessConnectionState.disconnected);

  String? _accessToken;

  LichessSessionManager({
    FlutterSecureStorage? secureStorage,
  }) : secureStorage = secureStorage ??
            ((Platform.environment.containsKey('FLUTTER_TEST') ||
                    WidgetsBinding.instance.toString().contains('TestWidgetsFlutterBinding'))
                ? InMemorySecureStorage()
                : const FlutterSecureStorage());

  /// Gets the active Lichess access token.
  String? get accessToken => _accessToken;

  /// Exposes active connection state.
  LichessConnectionState get connectionState => connectionStateNotifier.value;

  /// Updates connection state and triggers listeners.
  void setConnectionState(LichessConnectionState state) {
    connectionStateNotifier.value = state;
  }

  /// Restores previous session from encrypted secure storage on startup.
  Future<bool> restoreSession() async {
    try {
      final token = await secureStorage.read(key: _keyToken);
      if (token != null && token.isNotEmpty) {
        _accessToken = token;
        setConnectionState(LichessConnectionState.connected);
        return true;
      }
    } catch (e) {
      debugPrint('Failed to restore Lichess session: $e');
    }
    setConnectionState(LichessConnectionState.disconnected);
    return false;
  }

  /// Commits a newly acquired token into secure storage.
  Future<void> saveSession(String token) async {
    _accessToken = token;
    await secureStorage.write(key: _keyToken, value: token);
    setConnectionState(LichessConnectionState.connected);
  }

  /// Clears active credentials from secure storage and resets state.
  Future<void> clearSession() async {
    _accessToken = null;
    await secureStorage.delete(key: _keyToken);
    setConnectionState(LichessConnectionState.disconnected);
  }
}
