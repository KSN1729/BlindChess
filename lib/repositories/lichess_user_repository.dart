import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/lichess_profile.dart';
import '../services/lichess_api_client.dart';

/// Repository responsible for loading and caching user profile statistics.
class LichessUserRepository {
  final LichessApiClient apiClient;

  final ValueNotifier<LichessProfile?> profileNotifier = ValueNotifier<LichessProfile?>(null);

  LichessUserRepository({
    required this.apiClient,
  });

  /// Gets the currently cached user profile.
  LichessProfile? get profile => profileNotifier.value;

  /// Fetches the profile from the Lichess account API and caches it.
  Future<LichessProfile> loadProfile() async {
    try {
      final json = await apiClient.get('/api/account');
      final newProfile = LichessProfile.fromJson(json);
      profileNotifier.value = newProfile;
      return newProfile;
    } catch (e) {
      debugPrint('Failed to load Lichess profile in repository: $e');
      rethrow;
    }
  }

  /// Clears cached profile details on logout.
  void clearProfile() {
    profileNotifier.value = null;
  }
}
