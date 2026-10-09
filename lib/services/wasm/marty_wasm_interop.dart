import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../../utils/logger.dart';

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

  Future<List<Map<String, dynamic>>> extractCredentialsFromVp(
    String vpJwt,
  ) async => (jsonDecode(_call('extract_credentials_from_vp', [vpJwt])) as List)
      .cast<Map<String, dynamic>>();

  String getVersion() => _call('get_version');
  String healthCheck() => _call('health_check');
}
