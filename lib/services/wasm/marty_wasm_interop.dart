/*
 * Marty WASM Interop Layer
 *
 * Provides Dart bindings to the marty-rs WASM module for web builds.
 * This enables real cryptographic operations for credential/presentation
 * generation in the web wallet.
 *
 * Usage:
 *   final wasm = MartyWasm.instance;
 *   await wasm.initialize();
 *   final key = await wasm.generateP256Key();
 *
 * Authors: Adam Burdett
 * Copyright (c) 2024-2025 Marty Trust Services
 */

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'dart:convert';
import 'dart:async';

import 'package:privacyidea_authenticator/utils/logger.dart';

/// Result of a WASM key generation operation
class WasmKeyResult {
  final String did;
  final Map<String, dynamic> jwk;
  final String keyId;

  WasmKeyResult({required this.did, required this.jwk, required this.keyId});

  factory WasmKeyResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return WasmKeyResult(
      did: json['did'] as String,
      jwk: json['jwk'] as Map<String, dynamic>,
      keyId: json['keyId'] as String,
    );
  }

  String get jwkJson => jsonEncode(jwk);
}

/// Result of credential creation
class WasmCredentialResult {
  final String jwt;
  final String credentialId;

  WasmCredentialResult({required this.jwt, required this.credentialId});

  factory WasmCredentialResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return WasmCredentialResult(
      jwt: json['jwt'] as String,
      credentialId: json['credentialId'] as String,
    );
  }
}

/// Result of JWT verification
class WasmVerifyResult {
  final bool valid;
  final Map<String, dynamic>? payload;
  final String? error;

  WasmVerifyResult({required this.valid, this.payload, this.error});

  factory WasmVerifyResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return WasmVerifyResult(
      valid: json['valid'] as bool,
      payload: json['payload'] as Map<String, dynamic>?,
      error: json['error'] as String?,
    );
  }
}

/// Singleton wrapper for marty-rs WASM module
class MartyWasm {
  static MartyWasm? _instance;
  static MartyWasm get instance => _instance ??= MartyWasm._();

  bool _initialized = false;
  js.JsObject? _wasmModule;

  MartyWasm._();

  /// Check if WASM module is available
  bool get isAvailable => _initialized && _wasmModule != null;

  /// Initialize the WASM module
  /// Call this once at app startup before using any WASM functions
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Check if the WASM module is already loaded in the global scope
      if (js.context.hasProperty('marty_rs')) {
        _wasmModule = js.context['marty_rs'] as js.JsObject?;
        _initialized = _wasmModule != null;
        Logger.info('MartyWasm: Module found in global scope');
      } else {
        // Try to load the WASM module dynamically
        await _loadWasmModule();
      }

      if (_initialized) {
        final health = _callWasmFunction('health_check') as String?;
        Logger.info('MartyWasm: Health check = $health');
      }
    } catch (e) {
      Logger.error('MartyWasm: Failed to initialize', error: e);
      _initialized = false;
    }
  }

  Future<void> _loadWasmModule() async {
    final completer = Completer<void>();

    // Create a script element to load the WASM JS wrapper
    final script = html.ScriptElement()
      ..type = 'module'
      ..text = '''
        import init, * as marty_rs from '/assets/packages/marty_rs/_marty_rs.js';

        async function loadMartyWasm() {
          await init('/assets/packages/marty_rs/_marty_rs_bg.wasm');
          window.marty_rs = marty_rs;
          window.dispatchEvent(new CustomEvent('marty_wasm_loaded'));
        }

        loadMartyWasm().catch(e => {
          console.error('Failed to load marty WASM:', e);
          window.dispatchEvent(new CustomEvent('marty_wasm_error', {detail: e.message}));
        });
      ''';

    // Listen for load completion
    html.window.addEventListener('marty_wasm_loaded', (event) {
      _wasmModule = js.context['marty_rs'] as js.JsObject?;
      _initialized = _wasmModule != null;
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    html.window.addEventListener('marty_wasm_error', (event) {
      if (!completer.isCompleted) {
        completer.completeError('Failed to load WASM module');
      }
    });

    html.document.head?.append(script);

    // Timeout after 10 seconds
    await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('WASM module load timeout');
      },
    );
  }

  /// Call a WASM function with error handling
  dynamic _callWasmFunction(String name, [List<dynamic>? args]) {
    if (!isAvailable) {
      throw StateError('MartyWasm not initialized. Call initialize() first.');
    }

    try {
      final result = _wasmModule!.callMethod(name, args);
      return result;
    } catch (e) {
      Logger.error('MartyWasm: Error calling $name', error: e);
      rethrow;
    }
  }

  Future<String> _callWasmFunctionAsync(
    String name, [
    List<dynamic>? args,
  ]) async {
    final result = _callWasmFunction(name, args);
    if (result is js.JsObject && js_util.hasProperty(result, 'then')) {
      final resolved = await js_util.promiseToFuture(result);
      return resolved as String;
    }
    return result as String;
  }

  // =========================================================================
  // Key Generation
  // =========================================================================

  /// Generate a P-256 key pair for OID4VCI
  Future<WasmKeyResult> generateP256Key() async {
    final result = _callWasmFunction('generate_p256_key') as String;
    return WasmKeyResult.fromJson(result);
  }

  /// Generate an Ed25519 key pair
  Future<WasmKeyResult> generateEd25519Key() async {
    final result = _callWasmFunction('generate_ed25519_key') as String;
    return WasmKeyResult.fromJson(result);
  }

  // =========================================================================
  // Credential Issuance (Issuer Side)
  // =========================================================================

  /// Create a verifiable credential and sign it as a JWT
  Future<WasmCredentialResult> createVerifiableCredential({
    required String issuerDid,
    required String issuerJwkJson,
    String? subjectId,
    required String credentialType,
    required Map<String, dynamic> claims,
    int? expirationSeconds,
  }) async {
    final result =
        _callWasmFunction('create_verifiable_credential', [
              issuerDid,
              issuerJwkJson,
              subjectId,
              credentialType,
              jsonEncode(claims),
              expirationSeconds,
            ])
            as String;
    return WasmCredentialResult.fromJson(result);
  }

  /// Create an OID4VCI credential offer
  Future<Map<String, dynamic>> createCredentialOffer({
    required String issuerUrl,
    required List<String> credentialTypes,
    String? preAuthorizedCode,
    bool userPinRequired = false,
  }) async {
    final result =
        _callWasmFunction('create_credential_offer', [
              issuerUrl,
              jsonEncode(credentialTypes),
              preAuthorizedCode,
              userPinRequired,
            ])
            as String;
    return jsonDecode(result) as Map<String, dynamic>;
  }

  // =========================================================================
  // Open Badges (OB2/OB3)
  // =========================================================================

  /// Issue an Open Badges v2 assertion.
  Future<Map<String, dynamic>> issueOpenBadgeV2({
    required Map<String, dynamic> request,
  }) async {
    final result =
        _callWasmFunction('open_badge_ob2_issue', [jsonEncode(request)])
            as String;
    return jsonDecode(result) as Map<String, dynamic>;
  }

  /// Verify an Open Badges v2 assertion.
  Future<Map<String, dynamic>> verifyOpenBadgeV2({
    required Map<String, dynamic> request,
  }) async {
    final result =
        _callWasmFunction('open_badge_ob2_verify', [jsonEncode(request)])
            as String;
    return jsonDecode(result) as Map<String, dynamic>;
  }

  /// Issue an Open Badges v3 credential (Data Integrity proof).
  Future<Map<String, dynamic>> issueOpenBadgeV3({
    required Map<String, dynamic> request,
  }) async {
    final result = await _callWasmFunctionAsync('open_badge_ob3_issue', [
      jsonEncode(request),
    ]);
    return jsonDecode(result) as Map<String, dynamic>;
  }

  /// Verify an Open Badges v3 credential (Data Integrity proof).
  Future<Map<String, dynamic>> verifyOpenBadgeV3({
    required Map<String, dynamic> request,
  }) async {
    final result = await _callWasmFunctionAsync('open_badge_ob3_verify', [
      jsonEncode(request),
    ]);
    return jsonDecode(result) as Map<String, dynamic>;
  }

  /// Generate a credential offer URI for QR code display
  String generateOfferUri({
    required String issuerUrl,
    required String offerId,
    String format = 'oid4vci',
  }) {
    return _callWasmFunction('generate_offer_uri', [issuerUrl, offerId, format])
        as String;
  }

  // =========================================================================
  // Presentation Creation (Holder Side)
  // =========================================================================

  /// Create a verifiable presentation from credentials
  Future<String> createPresentation({
    required String holderDid,
    required String holderJwkJson,
    required List<String> credentialJwts,
    required String audience,
    String? nonce,
  }) async {
    return _callWasmFunction('create_presentation', [
          holderDid,
          holderJwkJson,
          jsonEncode(credentialJwts),
          audience,
          nonce,
        ])
        as String;
  }

  /// Create an OID4VP authorization response
  Future<Map<String, dynamic>> createAuthorizationResponse({
    required String vpToken,
    required Map<String, dynamic> presentationSubmission,
    String? state,
  }) async {
    final result =
        _callWasmFunction('create_authorization_response', [
              vpToken,
              jsonEncode(presentationSubmission),
              state,
            ])
            as String;
    return jsonDecode(result) as Map<String, dynamic>;
  }

  // =========================================================================
  // Verification (Light - claims only, no signature verification)
  // =========================================================================

  /// Verify a JWT structure and claims (does NOT verify cryptographic signature)
  Future<WasmVerifyResult> verifyJwtClaims({
    required String jwt,
    String? expectedIssuer,
    String? expectedAudience,
  }) async {
    final result =
        _callWasmFunction('verify_jwt_claims', [
              jwt,
              expectedIssuer,
              expectedAudience,
            ])
            as String;
    return WasmVerifyResult.fromJson(result);
  }

  /// Extract credentials from a VP JWT
  Future<List<Map<String, dynamic>>> extractCredentialsFromVp(
    String vpJwt,
  ) async {
    final result =
        _callWasmFunction('extract_credentials_from_vp', [vpJwt]) as String;
    final list = jsonDecode(result) as List;
    return list.cast<Map<String, dynamic>>();
  }

  // =========================================================================
  // Utility
  // =========================================================================

  /// Get the WASM module version
  String getVersion() {
    return _callWasmFunction('get_version') as String;
  }

  /// Health check
  String healthCheck() {
    return _callWasmFunction('health_check') as String;
  }
}
