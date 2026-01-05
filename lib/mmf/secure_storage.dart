/*
 * privacyIDEA Authenticator
 *
 * Authors: Adam Burdett <adam.burdett@netknights.it>
 *
 * Copyright (c) 2025 NetKnights GmbH
 *
 * Licensed under the Apache License, Version 2.0 (the 'License');
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an 'AS IS' BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:typed_data';

/// MMF Secure Storage Interface.
///
/// Provides secure, encrypted storage for sensitive data. This is an MMF
/// infrastructure interface - credential-agnostic storage operations.
/// Marty implements this using platform-specific secure storage
/// (iOS Keychain, Android EncryptedSharedPreferences, etc.).
abstract class ISecureStorage {
  /// Store a string value securely.
  Future<void> write({
    required String key,
    required String value,
    StorageOptions? options,
  });

  /// Read a string value from secure storage.
  Future<String?> read(String key);

  /// Store binary data securely.
  Future<void> writeBytes({
    required String key,
    required Uint8List value,
    StorageOptions? options,
  });

  /// Read binary data from secure storage.
  Future<Uint8List?> readBytes(String key);

  /// Delete a value from secure storage.
  Future<void> delete(String key);

  /// Delete all values from secure storage.
  Future<void> deleteAll();

  /// Check if a key exists in secure storage.
  Future<bool> containsKey(String key);

  /// List all keys in secure storage.
  Future<List<String>> getAllKeys();

  /// Get storage metadata for a key.
  Future<StorageMetadata?> getMetadata(String key);
}

/// Options for secure storage operations.
class StorageOptions {
  /// Accessibility level for iOS Keychain.
  final KeychainAccessibility? keychainAccessibility;

  /// Whether to require biometric authentication to access.
  final bool requireBiometric;

  /// Whether to sync across devices (iCloud Keychain on iOS).
  final bool syncable;

  /// Access group for sharing between apps (iOS).
  final String? accessGroup;

  const StorageOptions({
    this.keychainAccessibility,
    this.requireBiometric = false,
    this.syncable = false,
    this.accessGroup,
  });

  /// Default options for credential storage.
  static const credentialDefaults = StorageOptions(
    keychainAccessibility: KeychainAccessibility.afterFirstUnlock,
    requireBiometric: false,
    syncable: false,
  );

  /// Options for highly sensitive data requiring biometric.
  static const biometricProtected = StorageOptions(
    keychainAccessibility: KeychainAccessibility.whenUnlockedThisDeviceOnly,
    requireBiometric: true,
    syncable: false,
  );
}

/// iOS Keychain accessibility levels.
enum KeychainAccessibility {
  /// Data can only be accessed while the device is unlocked.
  whenUnlocked,

  /// Data can only be accessed while the device is unlocked, not backed up.
  whenUnlockedThisDeviceOnly,

  /// Data is accessible after first unlock until reboot.
  afterFirstUnlock,

  /// Data is accessible after first unlock until reboot, not backed up.
  afterFirstUnlockThisDeviceOnly,

  /// Data is always accessible (not recommended for sensitive data).
  always,

  /// Data requires passcode to be set.
  whenPasscodeSetThisDeviceOnly,
}

/// Metadata about a stored value.
class StorageMetadata {
  /// Storage key
  final String key;

  /// When the value was created
  final DateTime? createdAt;

  /// When the value was last modified
  final DateTime? modifiedAt;

  /// Size in bytes
  final int? sizeBytes;

  /// Whether biometric is required to access
  final bool requiresBiometric;

  const StorageMetadata({
    required this.key,
    this.createdAt,
    this.modifiedAt,
    this.sizeBytes,
    this.requiresBiometric = false,
  });
}
