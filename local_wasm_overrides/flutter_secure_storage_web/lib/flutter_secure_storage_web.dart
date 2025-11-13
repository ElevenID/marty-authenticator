/*
 * WASM-compatible implementation of flutter_secure_storage_web
 *
 * This override replaces the original flutter_secure_storage_web package
 * to resolve dart:html, dart:js, and dart:js_util compatibility issues with WASM builds.
 *
 * It provides the same interface but uses SharedPreferences as the storage mechanism
 * with basic data obfuscation.
 */

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WASM-compatible implementation of FlutterSecureStorage for web
class FlutterSecureStorageWebPlugin extends FlutterSecureStoragePlatform {
  static void registerWith(registrar) {
    FlutterSecureStoragePlatform.instance = FlutterSecureStorageWebPlugin();
  }

  static const String _keyPrefix = '__flutter_secure_storage__';

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final fullKey = _getFullKey(key, options);
    return prefs.containsKey(fullKey);
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final fullKey = _getFullKey(key, options);
    await prefs.remove(fullKey);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final prefix = _getPrefix(options);

    for (final key in keys) {
      if (key.startsWith(prefix)) {
        await prefs.remove(key);
      }
    }
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final fullKey = _getFullKey(key, options);
    final obfuscatedValue = prefs.getString(fullKey);

    if (obfuscatedValue == null) return null;

    return _deobfuscate(obfuscatedValue);
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final prefix = _getPrefix(options);
    final result = <String, String>{};

    for (final fullKey in keys) {
      if (fullKey.startsWith(prefix)) {
        final value = prefs.getString(fullKey);
        if (value != null) {
          final originalKey = fullKey.substring(prefix.length);
          result[originalKey] = _deobfuscate(value);
        }
      }
    }

    return result;
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final fullKey = _getFullKey(key, options);
    final obfuscatedValue = _obfuscate(value);

    await prefs.setString(fullKey, obfuscatedValue);
  }

  /// Generate the full key including prefix and database name
  String _getFullKey(String key, Map<String, String> options) {
    return _getPrefix(options) + key;
  }

  /// Generate the prefix based on options
  String _getPrefix(Map<String, String> options) {
    final dbName = options['dbName'] ?? 'default';
    return '$_keyPrefix${dbName}_';
  }

  /// Simple obfuscation using base64 encoding
  /// Note: This provides basic obfuscation but is not as secure as native secure storage
  String _obfuscate(String value) {
    final bytes = utf8.encode(value);
    return base64Encode(bytes);
  }

  /// Reverse the obfuscation
  String _deobfuscate(String obfuscatedValue) {
    try {
      final bytes = base64Decode(obfuscatedValue);
      return utf8.decode(bytes);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to deobfuscate value: $e');
      }
      // Return original value as fallback for migration
      return obfuscatedValue;
    }
  }
}
