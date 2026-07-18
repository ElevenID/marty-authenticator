import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../../utils/logger.dart';

class WasmKeyResult {
  final String did;
  final Map<String, dynamic> jwk;
  final String keyId;

  WasmKeyResult({required this.did, required this.jwk, required this.keyId});

  factory WasmKeyResult.fromJson(String source) {
    final value = jsonDecode(source) as Map<String, dynamic>;
    return WasmKeyResult(
      did: value['did'] as String,
      jwk: value['jwk'] as Map<String, dynamic>,
      keyId: value['keyId'] as String,
    );
  }

  String get jwkJson => jsonEncode(jwk);
}

class WasmCredentialResult {
  final String jwt;
  final String credentialId;

  WasmCredentialResult({required this.jwt, required this.credentialId});

  factory WasmCredentialResult.fromJson(String source) {
    final value = jsonDecode(source) as Map<String, dynamic>;
    return WasmCredentialResult(
      jwt: value['jwt'] as String,
      credentialId: value['credentialId'] as String,
    );
  }
}

class WasmVerifyResult {
  final bool valid;
  final Map<String, dynamic>? payload;
  final String? error;

  WasmVerifyResult({required this.valid, this.payload, this.error});

  factory WasmVerifyResult.fromJson(String source) {
    final value = jsonDecode(source) as Map<String, dynamic>;
    return WasmVerifyResult(
      valid: value['valid'] as bool,
      payload: value['payload'] as Map<String, dynamic>?,
      error: value['error'] as String?,
    );
  }
}

/// Modern Dart JS-interop wrapper for the marty-rs WebAssembly module.
class MartyWasm {
  static MartyWasm? _instance;
  static MartyWasm get instance => _instance ??= MartyWasm._();

  MartyWasm._();

  JSObject? _module;

  bool get isAvailable => _module != null;

  Future<void> initialize() async {
    if (isAvailable) return;
    for (var attempt = 0; attempt < 100; attempt++) {
      final candidate = globalContext['marty_rs'];
      if (candidate != null && candidate.isA<JSObject>()) {
        _module = candidate as JSObject;
        Logger.info('MartyWasm: module initialized');
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw TimeoutException('marty-rs WASM module did not initialize');
  }

  String _call(String name, [List<Object?> arguments = const []]) {
    final module = _module;
    if (module == null) {
      throw StateError('MartyWasm not initialized. Call initialize() first.');
    }
    final result = module.callMethodVarArgs<JSAny?>(
      name.toJS,
      arguments.map((value) => value?.jsify()).toList(),
    );
    final dartResult = result?.dartify();
    if (dartResult is! String) {
      throw StateError(
        '$name returned ${dartResult.runtimeType}, expected String',
      );
    }
    return dartResult;
  }

  Future<WasmKeyResult> generateP256Key() async =>
      WasmKeyResult.fromJson(_call('generate_p256_key'));

  Future<WasmKeyResult> generateEd25519Key() async =>
      WasmKeyResult.fromJson(_call('generate_ed25519_key'));

  Future<WasmCredentialResult> createVerifiableCredential({
    required String issuerDid,
    required String issuerJwkJson,
    String? subjectId,
    required String credentialType,
    required Map<String, dynamic> claims,
    int? expirationSeconds,
  }) async => WasmCredentialResult.fromJson(
    _call('create_verifiable_credential', [
      issuerDid,
      issuerJwkJson,
      subjectId,
      credentialType,
      jsonEncode(claims),
      expirationSeconds,
    ]),
  );

  Future<Map<String, dynamic>> createCredentialOffer({
    required String issuerUrl,
    required List<String> credentialTypes,
    String? preAuthorizedCode,
    bool userPinRequired = false,
  }) async =>
      jsonDecode(
            _call('create_credential_offer', [
              issuerUrl,
              jsonEncode(credentialTypes),
              preAuthorizedCode,
              userPinRequired,
            ]),
          )
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> issueOpenBadgeV2({
    required Map<String, dynamic> request,
  }) async => throw UnsupportedError(
    'Open Badges issuance is not exported by the current marty-rs WASM build',
  );

  Future<Map<String, dynamic>> verifyOpenBadgeV2({
    required Map<String, dynamic> request,
  }) async => throw UnsupportedError(
    'Open Badges verification is not exported by the current marty-rs WASM build',
  );

  Future<Map<String, dynamic>> issueOpenBadgeV3({
    required Map<String, dynamic> request,
  }) async => throw UnsupportedError(
    'Open Badges issuance is not exported by the current marty-rs WASM build',
  );

  Future<Map<String, dynamic>> verifyOpenBadgeV3({
    required Map<String, dynamic> request,
  }) async => throw UnsupportedError(
    'Open Badges verification is not exported by the current marty-rs WASM build',
  );

  String generateOfferUri({
    required String issuerUrl,
    required String offerId,
    String format = 'oid4vci',
  }) => _call('generate_offer_uri', [issuerUrl, offerId, format]);

  Future<String> createPresentation({
    required String holderDid,
    required String holderJwkJson,
    required List<String> credentialJwts,
    required String audience,
    String? nonce,
  }) async => _call('create_presentation', [
    holderDid,
    holderJwkJson,
    jsonEncode(credentialJwts),
    audience,
    nonce,
  ]);

  Future<Map<String, dynamic>> createAuthorizationResponse({
    required String vpToken,
    required Map<String, dynamic> presentationSubmission,
    String? state,
  }) async =>
      jsonDecode(
            _call('create_authorization_response', [
              vpToken,
              jsonEncode(presentationSubmission),
              state,
            ]),
          )
          as Map<String, dynamic>;

  Future<WasmVerifyResult> verifyJwtClaims({
    required String jwt,
    String? expectedIssuer,
    String? expectedAudience,
  }) async => WasmVerifyResult.fromJson(
    _call('verify_jwt_claims', [jwt, expectedIssuer, expectedAudience]),
  );

  Future<List<Map<String, dynamic>>> extractCredentialsFromVp(
    String vpJwt,
  ) async => (jsonDecode(_call('extract_credentials_from_vp', [vpJwt])) as List)
      .cast<Map<String, dynamic>>();

  String getVersion() => _call('get_version');
  String healthCheck() => _call('health_check');
}
