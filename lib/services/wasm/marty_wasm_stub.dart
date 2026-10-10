/*
 * Marty WASM Stub for non-web platforms
 *
 * Provides a stub implementation that throws on mobile/desktop.
 * Web-specific implementation is in marty_wasm_interop.dart
 *
 * Authors: Adam Burdett
 * Copyright (c) 2024-2025 Marty Trust Services
 */

import 'dart:async';

/// Stub wrapper for non-web platforms
class MartyWasm {
  static MartyWasm? _instance;
  static MartyWasm get instance => _instance ??= MartyWasm._();

  MartyWasm._();

  /// WASM is never available on non-web platforms
  bool get isAvailable => false;

  /// Initialize - no-op on non-web
  Future<void> initialize() async {
    // WASM not available on mobile/desktop - use native SpruceID SDK instead
  }

  Future<Map<String, dynamic>> createCredentialOffer({
    required String issuerUrl,
    required List<String> credentialTypes,
    String? preAuthorizedCode,
    bool userPinRequired = false,
  }) async {
    throw UnsupportedError('WASM not available on this platform');
  }

  Future<Map<String, dynamic>> issueOpenBadgeV2({
    required Map<String, dynamic> request,
  }) async {
    throw UnsupportedError('WASM not available on this platform');
  }

  Future<Map<String, dynamic>> verifyOpenBadgeV2({
    required Map<String, dynamic> request,
  }) async {
    throw UnsupportedError('WASM not available on this platform');
  }

  Future<Map<String, dynamic>> issueOpenBadgeV3({
    required Map<String, dynamic> request,
  }) async {
    throw UnsupportedError('WASM not available on this platform');
  }

  Future<Map<String, dynamic>> verifyOpenBadgeV3({
    required Map<String, dynamic> request,
  }) async {
    throw UnsupportedError('WASM not available on this platform');
  }

  String generateOfferUri({
    required String issuerUrl,
    required String offerId,
    String format = 'oid4vci',
  }) {
    throw UnsupportedError('WASM not available on this platform');
  }

  Future<Map<String, dynamic>> createAuthorizationResponse({
    required String vpToken,
    required Map<String, dynamic> presentationSubmission,
    String? state,
  }) async {
    throw UnsupportedError('WASM not available on this platform');
  }

  String getVersion() {
    throw UnsupportedError('WASM not available on this platform');
  }

  String healthCheck() {
    throw UnsupportedError('WASM not available on this platform');
  }
}
