/*
 * Marty Authenticator
 *
 * MartySecureStorage - Secure storage for Marty push service credentials
 *
 * This class handles persistent storage for:
 * - Server public key (for challenge signature verification)
 * - Device registration ID
 * - Device private key (for challenge response signing)
 *
 * Uses FlutterSecureStorage for encrypted storage on mobile platforms.
 */

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/logger.dart';

/// Keys used for secure storage
class MartyStorageKeys {
  static const String serverPublicKey = 'marty_server_public_key';
  static const String deviceId = 'marty_device_id';
  static const String registrationId = 'marty_registration_id';
  static const String organizationId = 'marty_organization_id';
  static const String privateKey = 'marty_private_key';
  static const String publicKeyKid = 'marty_public_key_kid';
}

/// Secure storage for Marty push service credentials.
///
/// Handles encryption and persistence of sensitive keys and identifiers
/// used for FCM push notification authentication.
class MartySecureStorage {
  static MartySecureStorage? _instance;

  final FlutterSecureStorage _storage;

  // In-memory cache for frequently accessed values
  String? _cachedServerPublicKey;
  String? _cachedDeviceId;
  String? _cachedPrivateKey;

  MartySecureStorage._({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
              synchronizable: false,
            ),
            webOptions: WebOptions(
              dbName: 'marty_secure_storage',
              publicKey: 'marty_storage_key',
            ),
          );

  /// Get singleton instance
  static MartySecureStorage get instance {
    _instance ??= MartySecureStorage._();
    return _instance!;
  }

  /// Create with custom storage (for testing)
  factory MartySecureStorage.withStorage(FlutterSecureStorage storage) {
    return MartySecureStorage._(storage: storage);
  }

  // ===========================================================================
  // Server Public Key
  // ===========================================================================

  /// Save the server's public key for challenge signature verification.
  ///
  /// [publicKey] - Base64 encoded public key in PKCS#8 DER format.
  Future<void> saveServerPublicKey(String publicKey) async {
    try {
      await _storage.write(
        key: MartyStorageKeys.serverPublicKey,
        value: publicKey,
      );
      _cachedServerPublicKey = publicKey;
      Logger.info('MartySecureStorage: Server public key saved');
    } catch (e, s) {
      Logger.error(
        'MartySecureStorage: Failed to save server public key',
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  /// Load the server's public key from secure storage.
  ///
  /// Returns the base64 encoded public key, or null if not stored.
  Future<String?> loadServerPublicKey() async {
    // Return cached value if available
    if (_cachedServerPublicKey != null) {
      return _cachedServerPublicKey;
    }

    try {
      final key = await _storage.read(key: MartyStorageKeys.serverPublicKey);
      _cachedServerPublicKey = key;
      if (key != null) {
        Logger.info('MartySecureStorage: Server public key loaded');
      }
      return key;
    } catch (e, s) {
      Logger.error(
        'MartySecureStorage: Failed to load server public key',
        error: e,
        stackTrace: s,
      );
      return null;
    }
  }

  /// Delete the server's public key.
  Future<void> deleteServerPublicKey() async {
    try {
      await _storage.delete(key: MartyStorageKeys.serverPublicKey);
      _cachedServerPublicKey = null;
      Logger.info('MartySecureStorage: Server public key deleted');
    } catch (e, s) {
      Logger.error(
        'MartySecureStorage: Failed to delete server public key',
        error: e,
        stackTrace: s,
      );
    }
  }

  // ===========================================================================
  // Device Registration
  // ===========================================================================

  /// Save device registration information.
  Future<void> saveDeviceRegistration({
    required String deviceId,
    required String registrationId,
    String? organizationId,
    String? publicKeyKid,
  }) async {
    try {
      await Future.wait([
        _storage.write(key: MartyStorageKeys.deviceId, value: deviceId),
        _storage.write(
          key: MartyStorageKeys.registrationId,
          value: registrationId,
        ),
        if (organizationId != null)
          _storage.write(
            key: MartyStorageKeys.organizationId,
            value: organizationId,
          ),
        if (publicKeyKid != null)
          _storage.write(
            key: MartyStorageKeys.publicKeyKid,
            value: publicKeyKid,
          ),
      ]);
      _cachedDeviceId = deviceId;
      Logger.info('MartySecureStorage: Device registration saved');
    } catch (e, s) {
      Logger.error(
        'MartySecureStorage: Failed to save device registration',
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  /// Load device ID from storage.
  Future<String?> loadDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId;
    }

    try {
      final id = await _storage.read(key: MartyStorageKeys.deviceId);
      _cachedDeviceId = id;
      return id;
    } catch (e) {
      Logger.error('MartySecureStorage: Failed to load device ID', error: e);
      return null;
    }
  }

  /// Load registration ID from storage.
  Future<String?> loadRegistrationId() async {
    try {
      return await _storage.read(key: MartyStorageKeys.registrationId);
    } catch (e) {
      Logger.error(
        'MartySecureStorage: Failed to load registration ID',
        error: e,
      );
      return null;
    }
  }

  /// Load organization ID from storage.
  Future<String?> loadOrganizationId() async {
    try {
      return await _storage.read(key: MartyStorageKeys.organizationId);
    } catch (e) {
      Logger.error(
        'MartySecureStorage: Failed to load organization ID',
        error: e,
      );
      return null;
    }
  }

  /// Load public key ID from storage.
  Future<String?> loadPublicKeyKid() async {
    try {
      return await _storage.read(key: MartyStorageKeys.publicKeyKid);
    } catch (e) {
      Logger.error(
        'MartySecureStorage: Failed to load public key ID',
        error: e,
      );
      return null;
    }
  }

  // ===========================================================================
  // Private Key
  // ===========================================================================

  /// Save the device's private key (PKCS#1 base64 encoded).
  Future<void> savePrivateKey(String privateKeyBase64) async {
    try {
      await _storage.write(
        key: MartyStorageKeys.privateKey,
        value: privateKeyBase64,
      );
      _cachedPrivateKey = privateKeyBase64;
      Logger.info('MartySecureStorage: Private key saved');
    } catch (e, s) {
      Logger.error(
        'MartySecureStorage: Failed to save private key',
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  /// Load the device's private key from storage.
  Future<String?> loadPrivateKey() async {
    if (_cachedPrivateKey != null) {
      return _cachedPrivateKey;
    }

    try {
      final key = await _storage.read(key: MartyStorageKeys.privateKey);
      _cachedPrivateKey = key;
      return key;
    } catch (e, s) {
      Logger.error(
        'MartySecureStorage: Failed to load private key',
        error: e,
        stackTrace: s,
      );
      return null;
    }
  }

  /// Delete the device's private key.
  Future<void> deletePrivateKey() async {
    try {
      await _storage.delete(key: MartyStorageKeys.privateKey);
      _cachedPrivateKey = null;
      Logger.info('MartySecureStorage: Private key deleted');
    } catch (e, s) {
      Logger.error(
        'MartySecureStorage: Failed to delete private key',
        error: e,
        stackTrace: s,
      );
    }
  }

  // ===========================================================================
  // Utility Methods
  // ===========================================================================

  /// Check if device is registered.
  Future<bool> isDeviceRegistered() async {
    final deviceId = await loadDeviceId();
    return deviceId != null && deviceId.isNotEmpty;
  }

  /// Clear all Marty-related storage (for logout/unregister).
  Future<void> clearAll() async {
    try {
      await Future.wait([
        _storage.delete(key: MartyStorageKeys.serverPublicKey),
        _storage.delete(key: MartyStorageKeys.deviceId),
        _storage.delete(key: MartyStorageKeys.registrationId),
        _storage.delete(key: MartyStorageKeys.organizationId),
        _storage.delete(key: MartyStorageKeys.privateKey),
        _storage.delete(key: MartyStorageKeys.publicKeyKid),
      ]);

      // Clear cache
      _cachedServerPublicKey = null;
      _cachedDeviceId = null;
      _cachedPrivateKey = null;

      Logger.info('MartySecureStorage: All storage cleared');
    } catch (e, s) {
      Logger.error(
        'MartySecureStorage: Failed to clear storage',
        error: e,
        stackTrace: s,
      );
    }
  }

  /// Clear the in-memory cache (useful for testing).
  void clearCache() {
    _cachedServerPublicKey = null;
    _cachedDeviceId = null;
    _cachedPrivateKey = null;
  }
}
