import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Exception thrown when Lichess returns an HTTP 429 rate limit block.
class LichessRateLimitException implements Exception {
  final String message;
  const LichessRateLimitException(this.message);
  @override
  String toString() => 'LichessRateLimitException: $message';
}

/// Exception thrown when Lichess returns an HTTP 401 unauthorized.
class LichessUnauthorizedException implements Exception {
  final String message;
  const LichessUnauthorizedException(this.message);
  @override
  String toString() => 'LichessUnauthorizedException: $message';
}

/// Exception thrown for standard Lichess API failures.
class LichessApiException implements Exception {
  final int statusCode;
  final String message;
  const LichessApiException(this.statusCode, this.message);

  /// Returns a clean, user-friendly error message parsed from the response body.
  String get userFriendlyMessage {
    try {
      final parsed = json.decode(message);
      if (parsed is Map && parsed.containsKey('error')) {
        return parsed['error'].toString();
      }
    } catch (_) {
      // Return raw message if it's not JSON
    }
    return message;
  }

  @override
  String toString() => 'LichessApiException (HTTP $statusCode): $message';
}

/// Exception thrown for underlying network failures.
class LichessNetworkException implements Exception {
  final String message;
  const LichessNetworkException(this.message);
  @override
  String toString() => 'LichessNetworkException: $message';
}

/// A robust, reusable, rate-limited API client for Lichess.
class LichessApiClient {
  /// Provider callback to supply the current authentication token.
  final String? Function() tokenProvider;

  /// HTTP client factory to instantiate HttpClient instances.
  HttpClient Function() clientFactory;

  /// Spacing between consecutive Lichess API requests (1 request per second limit).
  final Duration rateLimitInterval;

  DateTime _lastRequestTime = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> _queueChain = Future.value();

  LichessApiClient({
    required this.tokenProvider,
    HttpClient Function()? clientFactory,
    Duration? rateLimitInterval,
  })  : rateLimitInterval = rateLimitInterval ??
            (Platform.environment.containsKey('FLUTTER_TEST')
                ? Duration.zero
                : const Duration(milliseconds: 1050)),
        clientFactory = clientFactory ?? (() => HttpClient());

  /// Resets the rate limiting queue chain. Intended for testing purposes.
  void resetQueue() {
    _queueChain = Future.value();
    _lastRequestTime = DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Executes an API request under rate-limiting serialization.
  Future<T> _executeWithRateLimit<T>(Future<T> Function() action) {
    if (rateLimitInterval == Duration.zero) {
      return action();
    }
    final completer = Completer<T>();
    _queueChain = _queueChain.catchError((_) {}).then((_) async {
      final now = DateTime.now();
      final elapsed = now.difference(_lastRequestTime);
      if (elapsed < rateLimitInterval) {
        await Future.delayed(rateLimitInterval - elapsed);
      }
      _lastRequestTime = DateTime.now();
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, stack) {
        completer.completeError(e, stack);
      }
    });
    return completer.future;
  }

  /// Sends an HTTP request with built-in retries, timeouts, and headers.
  Future<HttpClientResponse> _requestWithRetry(
    Uri uri,
    String method, {
    String? body,
    Map<String, String>? headers,
    int maxRetries = 3,
  }) async {
    int attempts = 0;
    while (true) {
      attempts++;
      try {
        final client = clientFactory();
        final request = await (method == 'POST'
                ? client.postUrl(uri)
                : client.getUrl(uri))
            .timeout(const Duration(seconds: 15));

        // User-Agent and Authorization headers
        request.headers.set('User-Agent', 'BlindChess/1.0.0 (contact: support@blindchess.org)');
        final token = tokenProvider();
        if (token != null) {
          request.headers.set('Authorization', 'Bearer $token');
        }

        // Custom headers
        headers?.forEach((key, val) {
          request.headers.set(key, val);
        });

        if (body != null) {
          request.write(body);
        }

        final response = await request.close().timeout(const Duration(seconds: 15));

        if (response.statusCode == 429) {
          throw const LichessRateLimitException('Rate limit exceeded.');
        }

        return response;
      } on Exception catch (e) {
        if (e is LichessRateLimitException || e is LichessUnauthorizedException) {
          rethrow;
        }
        if (attempts >= maxRetries) {
          throw LichessNetworkException('Request failed after $maxRetries attempts: $e');
        }
        // Exponential backoff
        final backoff = Duration(milliseconds: 500 * (1 << (attempts - 1)));
        await Future.delayed(backoff);
      }
    }
  }

  /// Makes a standard GET request returning a JSON map.
  Future<Map<String, dynamic>> get(String path, {Map<String, String>? headers}) {
    return _executeWithRateLimit(() async {
      final response = await _requestWithRetry(
        Uri.parse('https://lichess.org$path'),
        'GET',
        headers: headers,
      );

      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode == 401) {
        throw const LichessUnauthorizedException('Unauthorized.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LichessApiException(response.statusCode, responseBody);
      }

      return json.decode(responseBody) as Map<String, dynamic>;
    });
  }

  /// Makes a standard GET request returning a raw String.
  Future<String> getString(String path, {Map<String, String>? headers}) {
    return _executeWithRateLimit(() async {
      final response = await _requestWithRetry(
        Uri.parse('https://lichess.org$path'),
        'GET',
        headers: headers,
      );

      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode == 401) {
        throw const LichessUnauthorizedException('Unauthorized.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LichessApiException(response.statusCode, responseBody);
      }

      return responseBody;
    });
  }

  /// Makes a standard POST request returning a JSON map.
  Future<Map<String, dynamic>> post(
    String path, {
    String? body,
    Map<String, String>? headers,
  }) {
    return _executeWithRateLimit(() async {
      final response = await _requestWithRetry(
        Uri.parse('https://lichess.org$path'),
        'POST',
        body: body,
        headers: headers,
      );

      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode == 401) {
        throw const LichessUnauthorizedException('Unauthorized.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LichessApiException(response.statusCode, responseBody);
      }

      return json.decode(responseBody) as Map<String, dynamic>;
    });
  }

  /// Streams a response line-by-line (e.g. for NDJSON streams).
  Future<Stream<String>> stream(String path, {String method = 'GET'}) async {
    final response = await _requestWithRetry(
      Uri.parse('https://lichess.org$path'),
      method,
    );

    if (response.statusCode == 401) {
      throw const LichessUnauthorizedException('Unauthorized.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.transform(utf8.decoder).join();
      throw LichessApiException(response.statusCode, body);
    }

    return response
        .transform(utf8.decoder)
        .transform(const LineSplitter());
  }
}
