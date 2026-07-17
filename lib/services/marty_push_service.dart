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
 * - SSE (Server-Sent Events) for real-time web push (replaces Firebase on web)
 * - Challenge response handling with cryptographic signatures
 * - Firebase token management
 * - Persistent secure storage for keys and registration
 */

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/asymmetric/api.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../utils/app_info_utils.dart';
import '../utils/firebase_utils.dart';
import '../utils/logger.dart';
import '../utils/rsa_utils.dart';
import '../models/marty_challenge.dart';
import '../repo/marty_secure_storage.dart';
import 'sse_push_service.dart';

/// Configuration for Marty Push Service
class MartyPushConfig {
  final String apiBaseUrl;
  final Duration pollInterval;
  final Duration requestTimeout;
  final bool useSSEOnWeb;

  const MartyPushConfig({
    required this.apiBaseUrl,
    this.pollInterval = const Duration(seconds: 5),
    this.requestTimeout = const Duration(seconds: 30),
    this.useSSEOnWeb = true,
  });

  /// Create config from environment or defaults
  factory MartyPushConfig.fromEnvironment() {
    final pollIntervalMs =
        int.tryParse(
          const String.fromEnvironment(
            'POLL_INTERVAL_MS',
            defaultValue: '5000',
          ),
        ) ??
        5000;

    final useSSE =
        const String.fromEnvironment('USE_SSE_PUSH', defaultValue: 'true') ==
        'true';

    return MartyPushConfig(
      apiBaseUrl: const String.fromEnvironment(
        'MARTY_API_URL',
        defaultValue: 'http://localhost:8000',
      ),
      pollInterval: Duration(milliseconds: pollIntervalMs),
      useSSEOnWeb: useSSE,
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
  final String?
  serverPublicKey; // Server's RSA public key for verifying challenge signatures

  const DeviceRegistrationResult({
    required this.deviceId,
    required this.registrationId,
    this.organizationId,
    this.publicKeyKid,
    required this.registeredAt,
    this.serverPublicKey,
  });

  factory DeviceRegistrationResult.fromJson(Map<String, dynamic> json) {
    return DeviceRegistrationResult(
      deviceId: json['device_id'] as String,
      registrationId: json['registration_id'] as String,
      organizationId: json['organization_id'] as String?,
      publicKeyKid: json['public_key_kid'] as String?,
      // Use current time if server doesn't return registered_at
      registeredAt: json['registered_at'] != null
          ? DateTime.parse(json['registered_at'] as String)
          : DateTime.now(),
      serverPublicKey: json['server_public_key'] as String?,
    );
  }
}

// NOTE: MartyPushChallenge has been replaced by MartyChallenge in lib/models/marty_challenge.dart
// The new model supports server-signed challenges with options for multi-choice responses.
// Import 'package:privacyidea_authenticator/models/marty_challenge.dart' to use it.

/// Marty Push Service
///
/// Handles push notification registration and challenge-response with Marty backend.
class MartyPushService {
  static MartyPushService? _instance;

  final MartyPushConfig config;
  final FirebaseUtils _firebaseUtils;
  final RsaUtils _rsaUtils;
  final http.Client _httpClient;
  final MartySecureStorage _secureStorage;

  String? _currentDeviceId;
  String? _currentOrganizationId;
  String? _currentUserId;
  String? _currentPublicKeyKid; // Key ID returned from registration
  RSAPrivateKey? _privateKey; // Private key for challenge signing
  String?
  _serverPublicKey; // Server's public key for verifying challenge signatures
  Timer? _pollTimer;
  bool _isPolling = false;
  bool _isInitialized = false;

  // SSE service for web real-time push
  SSEPushService? _sseService;
  StreamSubscription<SSEPushChallenge>? _sseSubscription;

  final List<void Function(MartyChallenge)> _challengeListeners = [];

  MartyPushService._({
    required this.config,
    FirebaseUtils? firebaseUtils,
    RsaUtils? rsaUtils,
    http.Client? httpClient,
    MartySecureStorage? secureStorage,
  }) : _firebaseUtils = firebaseUtils ?? FirebaseUtils(),
       _rsaUtils = rsaUtils ?? const RsaUtils(),
       _httpClient = httpClient ?? http.Client(),
       _secureStorage = secureStorage ?? MartySecureStorage.instance;

  /// Get singleton instance
  static MartyPushService get instance {
    _instance ??= MartyPushService._(config: MartyPushConfig.fromEnvironment());
    return _instance!;
  }

  /// Set the singleton instance (for testing/web test builds)
  /// This allows replacing the singleton with a test instance.
  static void setInstance(MartyPushService instance) {
    _instance = instance;
  }

  /// Reset the singleton instance (for testing)
  static void resetInstance() {
    _instance = null;
  }

  /// Create with custom config (for testing)
  factory MartyPushService.withConfig(
    MartyPushConfig config, {
    FirebaseUtils? firebaseUtils,
    RsaUtils? rsaUtils,
    http.Client? httpClient,
    MartySecureStorage? secureStorage,
  }) {
    return MartyPushService._(
      config: config,
      firebaseUtils: firebaseUtils,
      rsaUtils: rsaUtils,
      httpClient: httpClient,
      secureStorage: secureStorage,
    );
  }

  /// Initialize the service, loading stored credentials.
  ///
  /// Should be called during app startup before using the service.
  Future<void> initialize() async {
    if (_isInitialized) return;

    Logger.info('MartyPushService: Initializing');

    // Load stored credentials
    _serverPublicKey = await _secureStorage.loadServerPublicKey();
    _currentDeviceId = await _secureStorage.loadDeviceId();
    _currentOrganizationId = await _secureStorage.loadOrganizationId();
    _currentPublicKeyKid = await _secureStorage.loadPublicKeyKid();

    // Load private key if stored
    final privateKeyBase64 = await _secureStorage.loadPrivateKey();
    if (privateKeyBase64 != null) {
      try {
        _privateKey = _rsaUtils.deserializeRSAPrivateKeyPKCS1(privateKeyBase64);
        Logger.info('MartyPushService: Private key loaded from storage');
      } catch (e) {
        Logger.error('MartyPushService: Failed to load private key', error: e);
      }
    }

    _isInitialized = true;
    Logger.info('MartyPushService: Initialized, deviceId: $_currentDeviceId');
  }

  /// Whether the service has been initialized.
  bool get isInitialized => _isInitialized;

  /// Whether a device is currently registered.
  bool get isRegistered =>
      _currentDeviceId != null && _currentDeviceId!.isNotEmpty;

  /// Get the server public key (for signature verification).
  String? get serverPublicKey => _serverPublicKey;

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

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id; // Android device ID
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
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
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
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
    print('registerDevice: Starting for user $userId');

    _currentUserId = userId;
    _currentOrganizationId = organizationId;

    print('registerDevice: Generating device ID...');
    _currentDeviceId = await generateDeviceId(organizationId: organizationId);
    print('registerDevice: Device ID generated: $_currentDeviceId');

    print('registerDevice: Getting Firebase token...');
    final fcmToken = await _getFirebaseToken();
    print('registerDevice: Firebase token obtained: $fcmToken');

    // Generate RSA keypair for challenge signature verification
    String? publicKeyBase64;
    if (generateKeyPair) {
      Logger.info('MartyPushService: Generating RSA keypair for device');
      print(
        'registerDevice: Generating RSA keypair (this may take a moment on web)...',
      );
      final keyPair = await _rsaUtils.generateRSAKeyPair();
      print('registerDevice: RSA keypair generated');
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

    print(
      'registerDevice: Making HTTP request to ${config.apiBaseUrl}/api/devices/register',
    );

    final response = await _httpClient
        .post(
          Uri.parse('${config.apiBaseUrl}/api/devices/register'),
          headers: {'Content-Type': 'application/json', 'X-User-ID': userId},
          body: jsonEncode(deviceInfo.toJson()),
        )
        .timeout(config.requestTimeout);

    print('registerDevice: HTTP response status: ${response.statusCode}');
    print('registerDevice: HTTP response body: ${response.body}');

    if (response.statusCode == 201) {
      final result = DeviceRegistrationResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      _currentPublicKeyKid = result.publicKeyKid;

      // Store server public key for signature verification
      if (result.serverPublicKey != null) {
        _serverPublicKey = result.serverPublicKey;
        await _secureStorage.saveServerPublicKey(result.serverPublicKey!);
        Logger.info('MartyPushService: Server public key received and stored');
      }

      // Persist device registration
      await _secureStorage.saveDeviceRegistration(
        deviceId: _currentDeviceId!,
        registrationId: result.registrationId,
        organizationId: organizationId,
        publicKeyKid: result.publicKeyKid,
      );

      // Persist private key if generated
      if (_privateKey != null) {
        final privateKeyBase64 = _rsaUtils.serializeRSAPrivateKeyPKCS1(
          _privateKey!,
        );
        await _secureStorage.savePrivateKey(privateKeyBase64);
      }

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

      // Clear secure storage
      await _secureStorage.clearAll();

      _currentDeviceId = null;
      _currentUserId = null;
      _currentOrganizationId = null;
      _privateKey = null;
      _serverPublicKey = null;
      _currentPublicKeyKid = null;

      return true;
    }

    return false;
  }

  /// Register device from QR code scan
  ///
  /// Called when user scans a push registration QR code from the web UI.
  /// QR format: marty://push-register?org={org_id}&api={api_url}&token={temp_token}&user={user_id}
  ///
  /// [qrData] - The parsed QR code content map containing org, api, token, user
  /// Returns the registration result with device ID and confirmation
  Future<Map<String, dynamic>> registerFromQRCode(
    Map<String, dynamic> qrData,
  ) async {
    // Use print instead of html.window.console.log for better visibility
    print('registerFromQRCode: Starting with qrData=$qrData');

    final organizationId = qrData['organization_id'] as String?;
    final apiUrl = qrData['api_url'] as String?;
    final registrationToken = qrData['registration_token'] as String?;
    final userId = qrData['user_id'] as String?;

    Logger.info(
      'MartyPushService: Registering from QR code for org=$organizationId',
    );
    print('registerFromQRCode: org=$organizationId, api=$apiUrl, user=$userId');

    if (registrationToken == null || userId == null) {
      throw Exception('Invalid QR code: missing token or user_id');
    }

    // Use the API URL from the QR code if provided
    final effectiveApiUrl = apiUrl ?? config.apiBaseUrl;

    print('registerFromQRCode: Calling registerDevice...');

    // First register the device normally
    final result = await registerDevice(
      userId: userId,
      organizationId: organizationId,
    );

    print(
      'registerFromQRCode: registerDevice completed, deviceId=${result.deviceId}',
    );

    // Then call the QR callback endpoint to confirm registration and link to session
    final callbackResponse = await _httpClient
        .post(
          Uri.parse('$effectiveApiUrl/api/devices/qr-callback'),
          headers: {'Content-Type': 'application/json', 'X-User-ID': userId},
          body: jsonEncode({
            'temp_token':
                registrationToken, // API expects temp_token not registration_token
            'device_id': result.deviceId,
            'fcm_token': 'no_firebase_token',
            'platform': 'web',
            'public_key': null, // Could include the public key if needed
          }),
        )
        .timeout(config.requestTimeout);

    print(
      'registerFromQRCode: QR callback response status: ${callbackResponse.statusCode}',
    );
    print(
      'registerFromQRCode: QR callback response body: ${callbackResponse.body}',
    );

    if (callbackResponse.statusCode == 200) {
      Logger.info('MartyPushService: QR registration callback successful');
      return {
        'success': true,
        'device_id': result.deviceId,
        'registration_id': result.registrationId,
        'organization_id': organizationId,
        'message': 'Push notifications enabled successfully',
      };
    } else {
      Logger.warning(
        'MartyPushService: QR callback failed: ${callbackResponse.statusCode}',
      );
      // Registration succeeded but callback failed - still return success
      // The device is registered, just the web UI won't get notified via SSE
      return {
        'success': true,
        'device_id': result.deviceId,
        'registration_id': result.registrationId,
        'organization_id': organizationId,
        'callback_failed': true,
        'message': 'Device registered but web notification may not update',
      };
    }
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
  void addChallengeListener(void Function(MartyChallenge) listener) {
    _challengeListeners.add(listener);
  }

  /// Remove a challenge listener
  void removeChallengeListener(void Function(MartyChallenge) listener) {
    _challengeListeners.remove(listener);
  }

  /// Notify all listeners of a new challenge.
  ///
  /// Called internally and by PushProvider when FCM messages are received.
  void notifyChallenge(MartyChallenge challenge) {
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

    // On web, prefer SSE for real-time notifications
    if (kIsWeb && config.useSSEOnWeb) {
      _startSSE();
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

    // Also stop SSE if running
    _stopSSE();
  }

  /// Start SSE connection for real-time push notifications (web only)
  void _startSSE() {
    if (_currentDeviceId == null) {
      Logger.warning('MartyPushService: Cannot start SSE - not registered');
      return;
    }

    Logger.info('MartyPushService: Starting SSE connection');

    _sseService ??= SSEPushService(
      config: SSEPushConfig(
        apiBaseUrl: config.apiBaseUrl,
        reconnectMinDelay: const Duration(seconds: 1),
        reconnectMaxDelay: const Duration(seconds: 30),
      ),
    );

    // Subscribe to SSE challenges
    _sseSubscription?.cancel();
    _sseSubscription = _sseService!.challenges.listen((sseChallenge) {
      // Convert SSE challenge to MartyChallenge
      final challenge = MartyChallenge.fromJson(sseChallenge.data);

      // Verify signature if server public key is available
      if (_serverPublicKey != null && challenge.signature.isNotEmpty) {
        // TODO: Verify signature using _serverPublicKey
        Logger.info('MartyPushService: Challenge received with signature');
      }

      notifyChallenge(challenge);
    });

    _sseService!.connect(_currentDeviceId!);
    _isPolling = true;
  }

  /// Stop SSE connection
  void _stopSSE() {
    _sseSubscription?.cancel();
    _sseSubscription = null;
    _sseService?.disconnect();
  }

  /// Whether SSE is connected (web only)
  bool get isSSEConnected => _sseService?.isConnected ?? false;

  /// SSE connection state stream (web only)
  Stream<SSEConnectionState>? get sseConnectionState =>
      _sseService?.connectionState;

  /// Poll for pending challenges
  Future<List<MartyChallenge>> _pollForChallenges() async {
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
              (json) => MartyChallenge.fromJson(json as Map<String, dynamic>),
            )
            .where((c) => !c.isExpired)
            .toList();

        for (final challenge in challenges) {
          notifyChallenge(challenge);
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
  Future<List<MartyChallenge>> getPendingChallenges() async {
    return _pollForChallenges();
  }

  /// Get the current private key for challenge signing
  RSAPrivateKey? get privateKey => _privateKey;

  /// Get the current public key ID
  String? get publicKeyKid => _currentPublicKeyKid;

  /// Respond to a push challenge
  ///
  /// [challenge] - The challenge to respond to
  /// [optionId] - The selected option ID (e.g., 'accept' or 'reject')
  /// [privateKey] - RSA private key for signing (uses stored key if not provided)
  Future<bool> respondToChallenge(
    MartyChallenge challenge, {
    required String optionId,
    RSAPrivateKey? privateKey,
  }) async {
    if (_currentDeviceId == null) {
      throw Exception('Device not registered');
    }

    Logger.info(
      'MartyPushService: Responding to challenge ${challenge.challengeId}: $optionId',
    );

    // Use provided key or fall back to stored key
    final keyToUse = privateKey ?? _privateKey;

    // Sign if signature is required and key is available
    String? signature;
    if (keyToUse != null && challenge.requireSignature) {
      // Sign the nonce with the private key using PKCS#1 SHA-256
      final signatureBytes = _rsaUtils.createRSASignature(
        keyToUse,
        utf8.encode(challenge.nonce),
      );
      signature = base64Encode(signatureBytes);
      Logger.info('MartyPushService: Challenge response signed');
    } else if (challenge.requireSignature && keyToUse == null) {
      Logger.warning('MartyPushService: No private key available for signing');
    }

    final response = await _httpClient
        .post(
          Uri.parse(
            '${config.apiBaseUrl}/api/push/challenges/${challenge.challengeId}/respond?device_id=${Uri.encodeComponent(_currentDeviceId!)}',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'option_id': optionId,
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
  final List<MartyChallenge> _injectedChallenges = [];

  TestMartyPushService({required MartyPushConfig config})
    : super._(
        config: config,
        firebaseUtils: NoFirebaseUtils(), // Use no-op Firebase for tests
      );

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
  void injectChallenge(MartyChallenge challenge) {
    _injectedChallenges.add(challenge);
    notifyChallenge(challenge);
  }

  /// Clear injected challenges
  void clearInjectedChallenges() {
    _injectedChallenges.clear();
  }
}
