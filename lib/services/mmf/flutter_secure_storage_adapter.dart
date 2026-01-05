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

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart' as fss;

import '../../mmf/secure_storage.dart';
import '../../utils/logger.dart';

/// Flutter Secure Storage backed implementation of ISecureStorage.
///
/// Uses flutter_secure_storage which wraps:
/// - iOS: Keychain Services
/// - Android: EncryptedSharedPreferences / Android Keystore
/// - macOS: Keychain Services
/// - Web: Not supported (throws)
class FlutterSecureStorageAdapter implements ISecureStorage {
  final fss.FlutterSecureStorage _storage;

  FlutterSecureStorageAdapter({fss.FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const fss.FlutterSecureStorage(
            aOptions: fss.AndroidOptions(encryptedSharedPreferences: true),
            iOptions: fss.IOSOptions(
              accessibility: fss.KeychainAccessibility.first_unlock,
            ),
          );

  @override
  Future<void> write({
    required String key,
    required String value,
    StorageOptions? options,
  }) async {
    try {
      await _storage.write(
        key: key,
        value: value,
        iOptions: _toIOSOptions(options),
        aOptions: _toAndroidOptions(options),
      );
    } catch (e) {
      Logger.error('Failed to write to secure storage', error: e);
      rethrow;
    }
  }

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      Logger.error('Failed to read from secure storage', error: e);
      rethrow;
    }
  }

  @override
  Future<void> writeBytes({
    required String key,
    required Uint8List value,
    StorageOptions? options,
  }) async {
    // Encode bytes as base64 for storage
    final base64Value = base64Encode(value);
    await write(key: key, value: base64Value, options: options);
  }

  @override
  Future<Uint8List?> readBytes(String key) async {
    final base64Value = await read(key);
    if (base64Value == null) return null;

    try {
      return base64Decode(base64Value);
    } catch (e) {
      Logger.error('Failed to decode bytes from secure storage', error: e);
      return null;
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      Logger.error('Failed to delete from secure storage', error: e);
      rethrow;
    }
  }

  @override
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      Logger.error('Failed to delete all from secure storage', error: e);
      rethrow;
    }
  }

  @override
  Future<bool> containsKey(String key) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      Logger.error('Failed to check key in secure storage', error: e);
      return false;
    }
  }

  @override
  Future<List<String>> getAllKeys() async {
    try {
      final all = await _storage.readAll();
      return all.keys.toList();
    } catch (e) {
      Logger.error('Failed to get all keys from secure storage', error: e);
      return [];
    }
  }

  @override
  Future<StorageMetadata?> getMetadata(String key) async {
    // flutter_secure_storage doesn't provide metadata
    // Return basic info if key exists
    final exists = await containsKey(key);
    if (!exists) return null;

    return StorageMetadata(
      key: key,
      requiresBiometric: false, // Not tracked by flutter_secure_storage
    );
  }

  // ============================================================================
  // Private helpers
  // ============================================================================

  fss.IOSOptions _toIOSOptions(StorageOptions? options) {
    if (options == null) {
      return const fss.IOSOptions(
        accessibility: fss.KeychainAccessibility.first_unlock,
      );
    }

    return fss.IOSOptions(
      accessibility: _toKeychainAccessibility(options.keychainAccessibility),
      synchronizable: options.syncable,
      groupId: options.accessGroup,
    );
  }

  fss.AndroidOptions _toAndroidOptions(StorageOptions? options) {
    return const fss.AndroidOptions(encryptedSharedPreferences: true);
  }

  fss.KeychainAccessibility _toKeychainAccessibility(
    KeychainAccessibility? accessibility,
  ) {
    switch (accessibility) {
      case KeychainAccessibility.whenUnlocked:
        return fss.KeychainAccessibility.unlocked;
      case KeychainAccessibility.whenUnlockedThisDeviceOnly:
        return fss.KeychainAccessibility.unlocked_this_device;
      case KeychainAccessibility.afterFirstUnlock:
        return fss.KeychainAccessibility.first_unlock;
      case KeychainAccessibility.afterFirstUnlockThisDeviceOnly:
        return fss.KeychainAccessibility.first_unlock_this_device;
      case KeychainAccessibility.always:
        return fss.KeychainAccessibility.first_unlock;
      case KeychainAccessibility.whenPasscodeSetThisDeviceOnly:
        return fss.KeychainAccessibility.passcode;
      case null:
        return fss.KeychainAccessibility.first_unlock;
    }
  }
}
