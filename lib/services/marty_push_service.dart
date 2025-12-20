/*
 * Marty Authenticator
 *
 * MartyPushService - Push notification service for Marty backend
 *
 * This service handles device registration and push notification communication
 * with the Marty backend, replacing privacyIDEA-specific push functionality.
 *
 * Features:
 * - Device registration with org-scoped device IDs
 * - Push challenge polling (for web/testing)
 * - Challenge response handling with cryptographic signatures
 * - Firebase token management
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/asymmetric/api.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../utils/app_info_utils.dart';
import '../utils/firebase_utils.dart';
import '../utils/logger.dart';
import '../utils/rsa_utils.dart';

/// Configuration for Marty Push Service
class MartyPushConfig {
  final String apiBaseUrl;
  final Duration pollInterval;
  final Duration requestTimeout;

  const MartyPushConfig({
    required this.apiBaseUrl,
    this.pollInterval = const Duration(seconds: 5),
    this.requestTimeout = const Duration(seconds: 30),
  });

  /// Create config from environment or defaults
  factory MartyPushConfig.fromEnvironment() {
    return MartyPushConfig(
      apiBaseUrl: const String.fromEnvironment(
        'MARTY_API_URL',
        defaultValue: 'http://localhost:8000',
      ),
    );
  }
}

/// Device information for registration
class MartyDeviceInfo {
  final String deviceId;
  final String platform;
  final String fcmToken;
  final String? appVersion;
  final String? osVersion;
  final String? deviceModel;
  final String? publicKey; // RSA public key in base64 PKCS#1 DER format

  const MartyDeviceInfo({
    required this.deviceId,
    required this.platform,
    required this.fcmToken,
    this.appVersion,
    this.osVersion,
    this.deviceModel,
    this.publicKey,
  });

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'platform': platform,
    'fcm_token': fcmToken,
    if (appVersion != null) 'app_version': appVersion,
    if (osVersion != null) 'os_version': osVersion,
    if (deviceModel != null) 'device_model': deviceModel,
    if (publicKey != null) 'public_key': publicKey,
  };
}

/// Registration response from Marty API
class DeviceRegistrationResult {
  final String deviceId;
  final String registrationId;
  final String? organizationId;
  final String? publicKeyKid; // SHA-256 thumbprint of registered public key
  final DateTime registeredAt;

  const DeviceRegistrationResult({
    required this.deviceId,
    required this.registrationId,
    this.organizationId,
    this.publicKeyKid,
    required this.registeredAt,
  });

  factory DeviceRegistrationResult.fromJson(Map<String, dynamic> json) {
    return DeviceRegistrationResult(
      deviceId: json['device_id'] as String,
      registrationId: json['registration_id'] as String,
      organizationId: json['organization_id'] as String?,
      publicKeyKid: json['public_key_kid'] as String?,
      registeredAt: DateTime.parse(json['registered_at'] as String),
    );
  }
}

/// Push challenge from Marty backend
class MartyPushChallenge {
  final String challengeId;
  final String title;
  final String question;
  final String nonce;
  final String? credentialId;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int ttlSeconds;

  const MartyPushChallenge({
    required this.challengeId,
    required this.title,
    required this.question,
    required this.nonce,
    this.credentialId,
    this.data = const {},
    required this.createdAt,
    required this.ttlSeconds,
  });

  factory MartyPushChallenge.fromJson(Map<String, dynamic> json) {
    return MartyPushChallenge(
      challengeId: json['challenge_id'] as String,
      title: json['title'] as String,
      question: json['question'] as String,
      nonce: json['nonce'] as String,
      credentialId: json['credential_id'] as String?,
      data: json['data'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
      ttlSeconds: json['ttl_seconds'] as int? ?? 120,
    );
  }

  /// Check if challenge has expired
  bool get isExpired {
    final expiresAt = createdAt.add(Duration(seconds: ttlSeconds));
    return DateTime.now().isAfter(expiresAt);
  }
}

/// Marty Push Service
///
/// Handles push notification registration and challenge-response with Marty backend.
class MartyPushService {
  static MartyPushService? _instance;

  final MartyPushConfig config;
  final FirebaseUtils _firebaseUtils;
  final RsaUtils _rsaUtils;
  final http.Client _httpClient;

  String? _currentDeviceId;
  String? _currentOrganizationId;
  String? _currentUserId;
  String? _currentPublicKeyKid; // Key ID returned from registration
  RSAPrivateKey? _privateKey; // Private key for challenge signing
  Timer? _pollTimer;
  bool _isPolling = false;

  final List<void Function(MartyPushChallenge)> _challengeListeners = [];

  MartyPushService._({
    required this.config,
    FirebaseUtils? firebaseUtils,
    RsaUtils? rsaUtils,
    http.Client? httpClient,
  }) : _firebaseUtils = firebaseUtils ?? FirebaseUtils(),
       _rsaUtils = rsaUtils ?? const RsaUtils(),
       _httpClient = httpClient ?? http.Client();

  /// Get singleton instance
  static MartyPushService get instance {
    _instance ??= MartyPushService._(config: MartyPushConfig.fromEnvironment());
    return _instance!;
  }

  /// Create with custom config (for testing)
  factory MartyPushService.withConfig(
    MartyPushConfig config, {
    FirebaseUtils? firebaseUtils,
    RsaUtils? rsaUtils,
    http.Client? httpClient,
  }) {
    return MartyPushService._(
      config: config,
      firebaseUtils: firebaseUtils,
      rsaUtils: rsaUtils,
      httpClient: httpClient,
    );
  }

  /// Current device ID (org-scoped)
  String? get currentDeviceId => _currentDeviceId;

  /// Current organization ID
  String? get currentOrganizationId => _currentOrganizationId;

  /// Generate a platform device ID
  Future<String> _getPlatformDeviceId() async {
    if (kIsWeb) {
      // For web, use a generated UUID stored in localStorage
      // This will be injected via URL params in test mode
      return 'web-${DateTime.now().millisecondsSinceEpoch}';
    }

    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id; // Android device ID
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'ios-unknown';
    }

    return 'unknown-${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Generate org-scoped device ID
  /// Format: <org_id>:<platform_device_id>
  Future<String> generateDeviceId({String? organizationId}) async {
    final platformId = await _getPlatformDeviceId();
    if (organizationId != null) {
      return '$organizationId:$platformId';
    }
    return platformId;
  }

  /// Get Firebase token
  Future<String> _getFirebaseToken() async {
    try {
      final token = await _firebaseUtils.getFBToken();
      return token ?? 'no_firebase_token';
    } catch (e) {
      Logger.warning(
        'Failed to get Firebase token, using placeholder',
        error: e,
      );
      return 'no_firebase_token';
    }
  }

  /// Get current platform string
  String _getPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// Register this device for push notifications
  ///
  /// [userId] - The authenticated user ID
  /// [organizationId] - Optional organization ID (will be prepended to device ID)
  /// [generateKeyPair] - Whether to generate RSA keypair for challenge signing (default: true)
  Future<DeviceRegistrationResult> registerDevice({
    required String userId,
    String? organizationId,
    bool generateKeyPair = true,
  }) async {
    Logger.info('MartyPushService: Registering device for user $userId');

    _currentUserId = userId;
    _currentOrganizationId = organizationId;
    _currentDeviceId = await generateDeviceId(organizationId: organizationId);

    final fcmToken = await _getFirebaseToken();

    // Generate RSA keypair for challenge signature verification
    String? publicKeyBase64;
    if (generateKeyPair) {
      Logger.info('MartyPushService: Generating RSA keypair for device');
      final keyPair = await _rsaUtils.generateRSAKeyPair();
      _privateKey = keyPair.privateKey;
      // Serialize public key as base64 PKCS#1 DER
      publicKeyBase64 = _rsaUtils.serializeRSAPublicKeyPKCS1(keyPair.publicKey);
      Logger.info('MartyPushService: RSA keypair generated');
    }

    final deviceInfo = MartyDeviceInfo(
      deviceId: _currentDeviceId!,
      platform: _getPlatform(),
      fcmToken: fcmToken,
      appVersion: InfoUtils.isInitialized
          ? InfoUtils.currentVersionString
          : null,
      osVersion: InfoUtils.isInitialized ? InfoUtils.platform : null,
      deviceModel: InfoUtils.isInitialized ? InfoUtils.deviceModel : null,
      publicKey: publicKeyBase64,
    );

    final response = await _httpClient
        .post(
          Uri.parse('${config.apiBaseUrl}/api/devices/register'),
          headers: {'Content-Type': 'application/json', 'X-User-ID': userId},
          body: jsonEncode(deviceInfo.toJson()),
        )
        .timeout(config.requestTimeout);

    if (response.statusCode == 201) {
      final result = DeviceRegistrationResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      _currentPublicKeyKid = result.publicKeyKid;
      Logger.info(
        'MartyPushService: Device registered: ${result.registrationId}, key: ${result.publicKeyKid}',
      );
      return result;
    } else {
      throw Exception(
        'Failed to register device: ${response.statusCode} - ${response.body}',
      );
    }
  }

  /// Unregister this device
  Future<bool> unregisterDevice() async {
    if (_currentDeviceId == null || _currentUserId == null) {
      Logger.warning('MartyPushService: No device registered');
      return false;
    }

    Logger.info('MartyPushService: Unregistering device $_currentDeviceId');

    final response = await _httpClient
        .delete(
          Uri.parse(
            '${config.apiBaseUrl}/api/devices/${Uri.encodeComponent(_currentDeviceId!)}',
          ),
          headers: {'X-User-ID': _currentUserId!},
        )
        .timeout(config.requestTimeout);

    if (response.statusCode == 204) {
      stopPolling();
      _currentDeviceId = null;
      _currentUserId = null;
      _currentOrganizationId = null;
      return true;
    }

    return false;
  }

  /// Update Firebase token
  /// Called when FCM token is refreshed
  Future<void> updateFirebaseToken(String newToken) async {
    if (_currentDeviceId == null || _currentUserId == null) {
      Logger.warning('MartyPushService: Cannot update token - not registered');
      return;
    }

    Logger.info('MartyPushService: Updating Firebase token');

    final deviceInfo = MartyDeviceInfo(
      deviceId: _currentDeviceId!,
      platform: _getPlatform(),
      fcmToken: newToken,
    );

    try {
      await _httpClient
          .post(
            Uri.parse('${config.apiBaseUrl}/api/devices/register'),
            headers: {
              'Content-Type': 'application/json',
              'X-User-ID': _currentUserId!,
            },
            body: jsonEncode(deviceInfo.toJson()),
          )
          .timeout(config.requestTimeout);
    } catch (e) {
      Logger.error('Failed to update Firebase token', error: e);
    }
  }

  // ===========================================================================
  // Push Challenge Handling
  // ===========================================================================

  /// Add a listener for incoming challenges
  void addChallengeListener(void Function(MartyPushChallenge) listener) {
    _challengeListeners.add(listener);
  }

  /// Remove a challenge listener
  void removeChallengeListener(void Function(MartyPushChallenge) listener) {
    _challengeListeners.remove(listener);
  }

  /// Notify all listeners of a new challenge
  void _notifyListeners(MartyPushChallenge challenge) {
    for (final listener in _challengeListeners) {
      try {
        listener(challenge);
      } catch (e) {
        Logger.error('Error in challenge listener', error: e);
      }
    }
  }

  /// Start polling for push challenges
  /// Used when Firebase push is not available (web, testing)
  void startPolling() {
    if (_isPolling) return;
    if (_currentDeviceId == null) {
      Logger.warning('MartyPushService: Cannot start polling - not registered');
      return;
    }

    Logger.info('MartyPushService: Starting challenge polling');
    _isPolling = true;

    _pollTimer = Timer.periodic(config.pollInterval, (_) async {
      await _pollForChallenges();
    });

    // Poll immediately
    _pollForChallenges();
  }

  /// Stop polling for challenges
  void stopPolling() {
    Logger.info('MartyPushService: Stopping challenge polling');
    _pollTimer?.cancel();
    _pollTimer = null;
    _isPolling = false;
  }

  /// Poll for pending challenges
  Future<List<MartyPushChallenge>> _pollForChallenges() async {
    if (_currentDeviceId == null) return [];

    try {
      final response = await _httpClient
          .get(
            Uri.parse(
              '${config.apiBaseUrl}/api/push/challenges?device_id=${Uri.encodeComponent(_currentDeviceId!)}',
            ),
          )
          .timeout(config.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final challengesJson = data['challenges'] as List<dynamic>? ?? [];

        final challenges = challengesJson
            .map(
              (json) =>
                  MartyPushChallenge.fromJson(json as Map<String, dynamic>),
            )
            .where((c) => !c.isExpired)
            .toList();

        for (final challenge in challenges) {
          _notifyListeners(challenge);
        }

        return challenges;
      }
    } catch (e) {
      Logger.warning(
        'MartyPushService: Failed to poll for challenges',
        error: e,
      );
    }

    return [];
  }

  /// Get pending challenges (one-time fetch)
  Future<List<MartyPushChallenge>> getPendingChallenges() async {
    return _pollForChallenges();
  }

  /// Get the current private key for challenge signing
  RSAPrivateKey? get privateKey => _privateKey;

  /// Get the current public key ID
  String? get publicKeyKid => _currentPublicKeyKid;

  /// Respond to a push challenge
  ///
  /// [challenge] - The challenge to respond to
  /// [accept] - Whether to accept or reject
  /// [privateKey] - RSA private key for signing (uses stored key if not provided)
  Future<bool> respondToChallenge(
    MartyPushChallenge challenge, {
    required bool accept,
    RSAPrivateKey? privateKey,
  }) async {
    if (_currentDeviceId == null) {
      throw Exception('Device not registered');
    }

    Logger.info(
      'MartyPushService: Responding to challenge ${challenge.challengeId}: ${accept ? 'accept' : 'reject'}',
    );

    // Use provided key or fall back to stored key
    final keyToUse = privateKey ?? _privateKey;

    String? signature;
    if (keyToUse != null && accept) {
      // Sign the nonce with the private key using PKCS#1 SHA-256
      final signatureBytes = _rsaUtils.createRSASignature(
        keyToUse,
        utf8.encode(challenge.nonce),
      );
      signature = base64Encode(signatureBytes);
      Logger.info('MartyPushService: Challenge response signed');
    } else if (accept && keyToUse == null) {
      Logger.warning('MartyPushService: No private key available for signing');
    }

    final response = await _httpClient
        .post(
          Uri.parse(
            '${config.apiBaseUrl}/api/push/challenges/${challenge.challengeId}/respond?device_id=${Uri.encodeComponent(_currentDeviceId!)}',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'response': accept ? 'accept' : 'reject',
            if (signature != null) 'signature': signature,
          }),
        )
        .timeout(config.requestTimeout);

    if (response.statusCode == 200) {
      Logger.info(
        'MartyPushService: Challenge response submitted successfully',
      );
      return true;
    }

    Logger.error(
      'MartyPushService: Failed to respond to challenge: ${response.statusCode}',
    );
    return false;
  }

  /// Dispose of resources
  void dispose() {
    stopPolling();
    _challengeListeners.clear();
  }
}

/// Test-only service for injecting challenges and device IDs
class TestMartyPushService extends MartyPushService {
  String? _injectedDeviceId;
  final List<MartyPushChallenge> _injectedChallenges = [];

  TestMartyPushService({required MartyPushConfig config})
    : super._(config: config);

  /// Set a test device ID
  void setTestDeviceId(String deviceId) {
    _injectedDeviceId = deviceId;
    _currentDeviceId = deviceId;
  }

  @override
  Future<String> generateDeviceId({String? organizationId}) async {
    if (_injectedDeviceId != null) {
      return _injectedDeviceId!;
    }
    return super.generateDeviceId(organizationId: organizationId);
  }

  /// Inject a challenge for testing
  void injectChallenge(MartyPushChallenge challenge) {
    _injectedChallenges.add(challenge);
    _notifyListeners(challenge);
  }

  /// Clear injected challenges
  void clearInjectedChallenges() {
    _injectedChallenges.clear();
  }
}
