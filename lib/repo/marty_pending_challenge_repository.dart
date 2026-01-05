/*
 * Marty Authenticator
 *
 * MartyPendingChallengeRepository - Storage for pending Marty challenges
 *
 * Handles persistent storage of Marty challenges received in the background
 * when the app is not in the foreground. These challenges are loaded when
 * the app opens and processed by the UI.
 */

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/marty_challenge.dart';
import '../utils/logger.dart';

/// Keys for SharedPreferences storage
class _PendingChallengeKeys {
  static const String pendingChallenges = 'marty_pending_challenges';
  static const String lastCleanup = 'marty_pending_challenges_cleanup';
}

/// Repository for storing and retrieving pending Marty challenges.
///
/// Challenges received while the app is in the background are stored here
/// and retrieved when the app comes to the foreground.
class MartyPendingChallengeRepository {
  static MartyPendingChallengeRepository? _instance;

  SharedPreferences? _prefs;

  MartyPendingChallengeRepository._();

  /// Get singleton instance
  static MartyPendingChallengeRepository get instance {
    _instance ??= MartyPendingChallengeRepository._();
    return _instance!;
  }

  /// Get SharedPreferences instance (lazy initialization)
  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Save a challenge received in the background.
  ///
  /// [challenge] - The Marty challenge to store.
  /// Returns true if successful.
  Future<bool> savePendingChallenge(MartyChallenge challenge) async {
    try {
      final prefs = await _preferences;
      final existing = await loadPendingChallenges();

      // Check if challenge already exists
      if (existing.any((c) => c.challengeId == challenge.challengeId)) {
        Logger.info(
          'MartyPendingChallengeRepository: Challenge ${challenge.challengeId} already exists',
        );
        return true;
      }

      // Add new challenge
      existing.add(challenge);

      // Serialize and store
      final jsonList = existing.map((c) => c.toJson()).toList();
      final jsonStr = jsonEncode(jsonList);

      final success = await prefs.setString(
        _PendingChallengeKeys.pendingChallenges,
        jsonStr,
      );

      if (success) {
        Logger.info(
          'MartyPendingChallengeRepository: Saved challenge ${challenge.challengeId}',
        );
      }

      return success;
    } catch (e, s) {
      Logger.error(
        'MartyPendingChallengeRepository: Failed to save challenge',
        error: e,
        stackTrace: s,
      );
      return false;
    }
  }

  /// Load all pending challenges.
  ///
  /// Returns a list of challenges, excluding expired ones.
  Future<List<MartyChallenge>> loadPendingChallenges() async {
    try {
      final prefs = await _preferences;
      final jsonStr = prefs.getString(_PendingChallengeKeys.pendingChallenges);

      if (jsonStr == null || jsonStr.isEmpty) {
        return [];
      }

      final jsonList = jsonDecode(jsonStr) as List<dynamic>;
      final challenges = <MartyChallenge>[];

      for (final json in jsonList) {
        try {
          final challenge = MartyChallenge.fromJson(
            json as Map<String, dynamic>,
          );

          // Only include non-expired challenges
          if (!challenge.isExpired) {
            challenges.add(challenge);
          }
        } catch (e) {
          Logger.warning(
            'MartyPendingChallengeRepository: Failed to parse challenge',
            error: e,
          );
        }
      }

      Logger.info(
        'MartyPendingChallengeRepository: Loaded ${challenges.length} pending challenges',
      );

      return challenges;
    } catch (e, s) {
      Logger.error(
        'MartyPendingChallengeRepository: Failed to load challenges',
        error: e,
        stackTrace: s,
      );
      return [];
    }
  }

  /// Remove a specific challenge by ID.
  ///
  /// [challengeId] - The ID of the challenge to remove.
  Future<bool> removeChallengeById(String challengeId) async {
    try {
      final prefs = await _preferences;
      final existing = await loadPendingChallenges();

      final filtered = existing
          .where((c) => c.challengeId != challengeId)
          .toList();

      if (filtered.length == existing.length) {
        // Challenge not found, nothing to remove
        return true;
      }

      final jsonList = filtered.map((c) => c.toJson()).toList();
      final jsonStr = jsonEncode(jsonList);

      final success = await prefs.setString(
        _PendingChallengeKeys.pendingChallenges,
        jsonStr,
      );

      if (success) {
        Logger.info(
          'MartyPendingChallengeRepository: Removed challenge $challengeId',
        );
      }

      return success;
    } catch (e, s) {
      Logger.error(
        'MartyPendingChallengeRepository: Failed to remove challenge',
        error: e,
        stackTrace: s,
      );
      return false;
    }
  }

  /// Clear all pending challenges.
  Future<bool> clearAll() async {
    try {
      final prefs = await _preferences;
      final success = await prefs.remove(
        _PendingChallengeKeys.pendingChallenges,
      );

      if (success) {
        Logger.info('MartyPendingChallengeRepository: Cleared all challenges');
      }

      return success;
    } catch (e, s) {
      Logger.error(
        'MartyPendingChallengeRepository: Failed to clear challenges',
        error: e,
        stackTrace: s,
      );
      return false;
    }
  }

  /// Remove expired challenges from storage.
  ///
  /// Should be called periodically to clean up old challenges.
  Future<void> cleanupExpired() async {
    try {
      final prefs = await _preferences;

      // Check if cleanup was done recently (within last hour)
      final lastCleanupMs =
          prefs.getInt(_PendingChallengeKeys.lastCleanup) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastCleanupMs < const Duration(hours: 1).inMilliseconds) {
        return;
      }

      // Load and filter challenges (loadPendingChallenges already filters expired)
      final challenges = await loadPendingChallenges();

      // Save back (this effectively removes expired ones)
      final jsonList = challenges.map((c) => c.toJson()).toList();
      final jsonStr = jsonEncode(jsonList);

      await prefs.setString(_PendingChallengeKeys.pendingChallenges, jsonStr);

      await prefs.setInt(_PendingChallengeKeys.lastCleanup, now);

      Logger.info(
        'MartyPendingChallengeRepository: Cleanup complete, ${challenges.length} active challenges',
      );
    } catch (e, s) {
      Logger.error(
        'MartyPendingChallengeRepository: Cleanup failed',
        error: e,
        stackTrace: s,
      );
    }
  }

  /// Get count of pending challenges.
  Future<int> get pendingCount async {
    final challenges = await loadPendingChallenges();
    return challenges.length;
  }
}

/// Static background handler for storing challenges when app is in background.
///
/// This function can be called from the Firebase background message handler
/// since it doesn't require any app state.
Future<void> savePendingMartyChallengeBackground(
  Map<String, dynamic> data,
) async {
  try {
    final challenge = MartyChallenge.fromFcmData(data);

    if (challenge.isExpired) {
      Logger.warning(
        'savePendingMartyChallengeBackground: Challenge already expired',
      );
      return;
    }

    await MartyPendingChallengeRepository.instance.savePendingChallenge(
      challenge,
    );
  } catch (e, s) {
    Logger.error(
      'savePendingMartyChallengeBackground: Failed to save challenge',
      error: e,
      stackTrace: s,
    );
  }
}
