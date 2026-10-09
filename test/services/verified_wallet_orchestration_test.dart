import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/rust/marty_bridge.dart/api.dart';
import 'package:marty_authenticator/services/remote_holder_pairing_service.dart';
import 'package:marty_authenticator/services/spruce_platform_service_extended.dart';
import 'package:marty_authenticator/services/verified_wallet_bridge.dart';
import 'package:marty_authenticator/services/wallet_credential_store.dart';

class _Holder extends RemoteHolderPairingService {
  bool closed = false;
  int signatures = 0;

  @override
  Future<String> renewIfDue({bool force = false}) async =>
      'paired-registration';

  @override
  Future<Map<String, String>> publicJwkForPurpose(String purpose) async {
    expect(purpose, 'presentation_signing');
    return const {
      'kty': 'EC',
      'crv': 'P-256',
      'x': 'public-x',
      'y': 'public-y',
    };
  }

  @override
  Future<Map<String, dynamic>> fetchIssuerKeys() async => const {
    'issuer_keys': [],
  };

  @override
  Future<List<int>> signInput({
    required String purpose,
    required List<int> signingInput,
  }) async {
    expect(purpose, 'presentation_signing');
    expect(signingInput, [1, 2, 3]);
    signatures++;
    return [4, 5, 6];
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}

class _Bridge implements VerifiedWalletBridge {
  bool rejectReceipt = false;
  String presentationRoute = 'oid4vp';
  int receiptCompletions = 0;
  int presentationParses = 0;
  int presentationPreparations = 0;
  int presentationCompletions = 0;

  @override
  Future<FrbPreparedSdJwtReceipt> prepareReceipt({
    required String offerUri,
    String? txCode,
    required String holderPublicJwkJson,
  }) async {
    expect(offerUri, 'openid-credential-offer://approved');
    expect(jsonDecode(holderPublicJwkJson), containsPair('kty', 'EC'));
    return FrbPreparedSdJwtReceipt(
      sessionId: 'receipt-session',
      signingInput: Uint8List.fromList([1, 2, 3]),
    );
  }

  @override
  Future<FrbVerifiedSdJwtReceipt> completeReceipt({
    required String sessionId,
    required List<int> remoteSignature,
    required String issuerSnapshotJson,
  }) async {
    receiptCompletions++;
    expect(sessionId, 'receipt-session');
    expect(remoteSignature, [4, 5, 6]);
    expect(jsonDecode(issuerSnapshotJson), contains('issuer_keys'));
    if (rejectReceipt) throw StateError('Rust rejected the receipt');
    return const FrbVerifiedSdJwtReceipt(
      credential: 'header.payload.signature~',
      issuer: 'https://issuer.example',
      credentialType: 'ExampleIdentity',
      format: 'dc+sd-jwt',
    );
  }

  @override
  Future<String> routePresentation({required String input}) async {
    expect(input, 'openid4vp://approved');
    return presentationRoute;
  }

  @override
  Future<FrbPresentationRequest> parsePresentation({
    required String requestUri,
  }) async {
    presentationParses++;
    expect(requestUri, 'openid4vp://approved');
    return FrbPresentationRequest(
      clientId: 'https://verifier.example',
      nonce: 'request-nonce',
      responseUri: 'https://verifier.example/response',
      requestDigest: 'bound-request-digest',
      queryType: 'dcql_query',
      dcqlQueryJson: jsonEncode({
        'credentials': [
          {
            'id': 'identity-query',
            'format': 'dc+sd-jwt',
            'claims': [
              {
                'path': ['given_name'],
              },
            ],
          },
        ],
      }),
    );
  }

  @override
  Future<FrbPreparedSdJwtPresentation> preparePresentation({
    required String requestUri,
    required String approvedRequestDigest,
    required String credential,
    required String queryId,
    required List<String> claimsToDisclose,
    required String issuerSnapshotJson,
    required String holderPublicJwkJson,
  }) async {
    presentationPreparations++;
    expect(requestUri, 'openid4vp://approved');
    expect(approvedRequestDigest, 'bound-request-digest');
    expect(credential, 'header.payload.signature~');
    expect(queryId, 'identity-query');
    expect(claimsToDisclose, ['given_name']);
    expect(jsonDecode(issuerSnapshotJson), contains('issuer_keys'));
    expect(jsonDecode(holderPublicJwkJson), containsPair('kty', 'EC'));
    return FrbPreparedSdJwtPresentation(
      sessionId: 'presentation-session',
      signingInput: Uint8List.fromList([1, 2, 3]),
    );
  }

  @override
  Future<FrbPresentationResponse> completePresentation({
    required String sessionId,
    required List<int> remoteSignature,
  }) async {
    presentationCompletions++;
    expect(sessionId, 'presentation-session');
    expect(remoteSignature, [4, 5, 6]);
    return const FrbPresentationResponse(
      ok: true,
      redirectUri: 'https://verifier.example/done',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('a Rust-rejected receipt is never stored', () async {
    final bridge = _Bridge()..rejectReceipt = true;
    final holders = <_Holder>[];
    final service = SpruceIdPlatformServiceExtended.withDependencies(
      bridge,
      () {
        final holder = _Holder();
        holders.add(holder);
        return holder;
      },
    );

    await expectLater(
      service.handleOID4VCOfferSDK(
        credentialOffer: 'openid-credential-offer://approved',
      ),
      throwsStateError,
    );
    expect(await WalletCredentialStore.getAll(), isEmpty);
    expect(bridge.receiptCompletions, 1);
    expect(holders.single.closed, isTrue);
  });

  test('only a completed Rust receipt enters the wallet', () async {
    final bridge = _Bridge();
    final service = SpruceIdPlatformServiceExtended.withDependencies(
      bridge,
      _Holder.new,
    );
    final result = await service.handleOID4VCOfferSDK(
      credentialOffer: 'openid-credential-offer://approved',
    );
    final stored = await WalletCredentialStore.getAll();
    expect(result['id'], stored.single.id);
    expect(stored.single.rawJson, 'header.payload.signature~');
    expect(stored.single.issuer, 'https://issuer.example');
    expect(bridge.receiptCompletions, 1);
  });

  test('unsupported mDoc route stops before presentation parsing', () async {
    final bridge = _Bridge()..presentationRoute = 'mdoc';
    final holders = <_Holder>[];
    final service = SpruceIdPlatformServiceExtended.withDependencies(
      bridge,
      () {
        final holder = _Holder();
        holders.add(holder);
        return holder;
      },
    );
    await expectLater(
      service.initiateOID4VPRequestSDK(
        presentationRequest: 'openid4vp://approved',
      ),
      throwsA(isA<UnsupportedError>()),
    );
    expect(bridge.presentationParses, 0);
    expect(holders.single.closed, isTrue);
  });

  test('presentation selection is exact and single use', () async {
    await WalletCredentialStore.store(
      StoredCredential(
        id: 'stored-identity',
        format: 'dc+sd-jwt',
        issuer: 'https://issuer.example',
        types: const ['ExampleIdentity'],
        rawJson: 'header.payload.signature~',
        issuedAt: DateTime.utc(2026, 10, 9),
      ),
    );
    final bridge = _Bridge();
    final service = SpruceIdPlatformServiceExtended.withDependencies(
      bridge,
      _Holder.new,
    );

    Future<UserSelectionRequiredException> initiate() async {
      try {
        await service.initiateOID4VPRequestSDK(
          presentationRequest: 'openid4vp://approved',
        );
      } on UserSelectionRequiredException catch (selection) {
        return selection;
      }
      throw StateError('A credential selection was required');
    }

    final first = await initiate();
    expect(first.matches.single['id'], 'stored-identity');
    expect(first.requestDetails['verifier'], 'https://verifier.example');
    await expectLater(
      service.completeOID4VPRequestSDK(
        sessionId: first.sessionId,
        selectedCredentialId: 'stored-identity',
        selectedFields: const ['credential/unrequested'],
      ),
      throwsStateError,
    );
    await expectLater(
      service.completeOID4VPRequestSDK(
        sessionId: first.sessionId,
        selectedCredentialId: 'stored-identity',
        selectedFields: const ['credential/given_name'],
      ),
      throwsStateError,
    );
    expect(bridge.presentationPreparations, 0);

    final second = await initiate();
    await expectLater(
      service.completeOID4VPRequestSDK(
        sessionId: second.sessionId,
        selectedCredentialId: 'stored-identity',
      ),
      throwsStateError,
    );
    final third = await initiate();
    await expectLater(
      service.completeOID4VPRequestSDK(
        sessionId: third.sessionId,
        selectedCredentialId: 'different-credential',
        selectedFields: const ['credential/given_name'],
      ),
      throwsStateError,
    );
    expect(bridge.presentationPreparations, 0);

    final fourth = await initiate();
    final result = await service.completeOID4VPRequestSDK(
      sessionId: fourth.sessionId,
      selectedCredentialId: 'stored-identity',
      selectedFields: const ['credential/given_name'],
    );
    expect(result, {
      'ok': true,
      'redirect_uri': 'https://verifier.example/done',
    });
    expect(bridge.presentationPreparations, 1);
    expect(bridge.presentationCompletions, 1);
  });
}
