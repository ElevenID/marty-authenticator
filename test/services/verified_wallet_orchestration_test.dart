import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/rust/marty_bridge.dart/api.dart';
import 'package:marty_authenticator/services/remote_holder_pairing_service.dart';
import 'package:marty_authenticator/services/spruce_platform_service_extended.dart';
import 'package:marty_authenticator/services/verified_wallet_bridge.dart';
import 'package:marty_authenticator/services/wallet_credential_store.dart';

// Preserve transport spelling; decoding/re-encoding before native validation
// would discard this duplicate member rather than let native reject it.
const _originalIssuerEvidence = ' { "issuer_keys": [], "issuer_keys": [] } ';
const _clientId = 'decentralized_identifier:did:web:verifier.example';
const _locator =
    'https://verifier.example/v1/flows/instances/11111111-2222-4333-8444-555555555555/request';
final _requestInput = Uri(
  scheme: 'openid4vp',
  host: 'authorize',
  queryParameters: {'client_id': _clientId, 'request_uri': _locator},
).toString();
String _governance(int read) => ' { "mock_native_governance": $read } ';
const _preparedHandle = 'aaaa1111-2222-4333-8444-555555555555';

class _Holder extends RemoteHolderPairingService {
  bool closed = false;
  int signatures = 0;
  int verifierReads = 0;
  int issuerReads = 0;
  int? failVerifierRead;
  int? failIssuerRead;
  Completer<void>? signatureGate;
  Completer<void>? signatureEntered;
  @override
  Future<String> fetchVerifierAuthorityJson({
    required String clientId,
    String? requestUri,
  }) async {
    expect(clientId, _clientId);
    expect(requestUri, _locator);
    verifierReads++;
    if (verifierReads == failVerifierRead) {
      throw StateError('Pairing evidence unavailable');
    }
    return _governance(verifierReads);
  }

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
  Future<String> fetchIssuerKeysJson() async {
    issuerReads++;
    if (issuerReads == failIssuerRead) {
      throw StateError('Issuer authority unavailable');
    }
    return _originalIssuerEvidence;
  }

  @override
  Future<List<int>> signInput({
    required String purpose,
    required List<int> signingInput,
  }) async {
    expect(purpose, 'presentation_signing');
    expect(signingInput, [1, 2, 3]);
    signatures++;
    signatureEntered?.complete();
    if (signatureGate != null) await signatureGate!.future;
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
  bool rejectPresentation = false;
  String presentationRoute = 'oid4vp';
  FrbPresentationRequest? requestOverride;
  String expectedQueryId = 'identity-query';
  List<String> expectedClaims = const ['given_name'];
  int receiptCompletions = 0;
  int receiptFinalizations = 0;
  bool rejectFinalization = false;
  int presentationParses = 0;
  int presentationPreparations = 0;
  int presentationCompletions = 0;
  int credentialReviews = 0;
  bool rejectReview = false;
  bool rejectPrepare = false;
  Completer<void>? reviewGate;
  Completer<void>? reviewEntered;
  Completer<void>? prepareGate;
  Completer<void>? prepareEntered;
  final Set<String> cancelled = {};
  final Set<String> reviewed = {};
  final List<String> events = [];
  @override
  Future<void> cancelPresentation({required String sessionId}) async {
    cancelled.add(sessionId);
    events.add('cancel:$sessionId');
  }

  String? reviewResponseOverride;
  final Set<String> rejectedCredentials = {};

  @override
  Future<String> reviewCredential({
    required String requestUri,
    required String governanceJson,
    required String credential,
    required String issuerSnapshotJson,
    required String holderPublicJwkJson,
  }) async {
    credentialReviews++;
    expect(requestUri, _locator);
    expect(governanceJson, _governance(1));
    final handle =
        '11111111-2222-4333-8444-${credentialReviews.toString().padLeft(12, '0')}';
    if (rejectedCredentials.contains(credential)) {
      throw StateError('Untrusted stored credential');
    }
    expect(credential, 'header.payload.signature~');
    expect(issuerSnapshotJson, _originalIssuerEvidence);
    expect(jsonDecode(holderPublicJwkJson), containsPair('kty', 'EC'));
    if (rejectReview) throw StateError('Native credential verification failed');
    final projection =
        reviewResponseOverride ??
        jsonEncode({
          'issuer': 'https://issuer.example',
          'credential_type': 'ExampleIdentity',
          'format': 'dc+sd-jwt',
          'protected_header': {
            'typ': 'dc+sd-jwt',
            'alg': 'ES256',
            'kid': 'issuer-signing-key',
          }.map((key, value) => MapEntry(key, jsonEncode(value))),
          'always_shared': {
            'iss': 'https://issuer.example',
            'sub': 'holder-identifier',
            'vct': 'ExampleIdentity',
          }.map((key, value) => MapEntry(key, jsonEncode(value))),
        });
    final request = _request();
    final raw = jsonEncode({
      'session_id': handle,
      'expires_at': DateTime.now()
          .toUtc()
          .add(const Duration(seconds: 30))
          .toIso8601String(),
      'request': {
        'client_id': request.clientId,
        'nonce': request.nonce,
        'response_uri': request.responseUri,
        'request_digest': request.requestDigest,
        'query_type': request.queryType,
        'dcql_query_json': request.dcqlQueryJson,
        'presentation_definition_json': request.presentationDefinitionJson,
      },
      'credential': jsonDecode(projection),
    });
    reviewed.add(handle);
    final gate = reviewGate;
    reviewGate = null;
    reviewEntered?.complete();
    reviewEntered = null;
    if (gate != null) await gate.future;
    return raw;
  }

  @override
  Future<FrbPreparedSdJwtReceipt> prepareReceipt({
    required String offerUri,
    String? txCode,
    required String holderPublicJwkJson,
    required String issuerSnapshotJson,
  }) async {
    expect(offerUri, 'openid-credential-offer://approved');
    expect(issuerSnapshotJson, _originalIssuerEvidence);
    events.add('receipt:prepare');
    expect(jsonDecode(holderPublicJwkJson), containsPair('kty', 'EC'));
    return FrbPreparedSdJwtReceipt(
      sessionId: 'receipt-session',
      signingInput: Uint8List.fromList([1, 2, 3]),
    );
  }

  @override
  Future<String> completeReceipt({
    required String sessionId,
    required List<int> remoteSignature,
    required String issuerSnapshotJson,
  }) async {
    receiptCompletions++;
    events.add('receipt:request');
    expect(sessionId, 'receipt-session');
    expect(remoteSignature, [4, 5, 6]);
    expect(issuerSnapshotJson, _originalIssuerEvidence);
    if (rejectReceipt) throw StateError('Rust rejected the receipt');
    return 'native-response-handle';
  }

  @override
  Future<FrbVerifiedSdJwtReceipt> finalizeReceipt({
    required String responseId,
    required String issuerSnapshotJson,
  }) async {
    receiptFinalizations++;
    events.add('receipt:finalize');
    expect(responseId, 'native-response-handle');
    expect(issuerSnapshotJson, _originalIssuerEvidence);
    if (rejectFinalization) {
      throw StateError('Authority changed during issuance');
    }
    return const FrbVerifiedSdJwtReceipt(
      credential: 'header.payload.signature~',
      issuer: 'https://issuer.example',
      credentialType: 'ExampleIdentity',
      format: 'dc+sd-jwt',
    );
  }

  @override
  Future<String> routePresentation({required String input}) async {
    return presentationRoute;
  }

  FrbPresentationRequest _request() {
    if (requestOverride != null) return requestOverride!;
    return FrbPresentationRequest(
      clientId: _clientId,
      nonce: 'request-nonce',
      responseUri: 'https://verifier.example/response',
      requestDigest: 'bound-request-digest',
      queryType: 'dcql_query',
      dcqlQueryJson: jsonEncode({
        'credentials': [
          {
            'id': 'identity-query',
            'format': 'dc+sd-jwt',
            'meta': {
              'vct_values': ['ExampleIdentity'],
            },
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
    required String sessionId,
    required String governanceJson,
    required List<String> claimsToDisclose,
    required String issuerSnapshotJson,
    required String holderPublicJwkJson,
  }) async {
    presentationPreparations++;
    events.add('prepare:$sessionId');
    expect(reviewed, contains(sessionId));
    expect(cancelled, isNot(contains(sessionId)));
    expect(governanceJson, _governance(1));
    if (rejectPrepare) throw StateError('Native authority changed');
    prepareEntered?.complete();
    if (prepareGate != null) await prepareGate!.future;
    expect(claimsToDisclose, expectedClaims);
    expect(issuerSnapshotJson, _originalIssuerEvidence);
    expect(jsonDecode(holderPublicJwkJson), containsPair('kty', 'EC'));
    return FrbPreparedSdJwtPresentation(
      sessionId: _preparedHandle,
      signingInput: Uint8List.fromList([1, 2, 3]),
    );
  }

  @override
  Future<FrbPresentationResponse> completePresentation({
    required String sessionId,
    required List<int> remoteSignature,
    required String governanceJson,
    required String issuerSnapshotJson,
    required String holderPublicJwkJson,
  }) async {
    expect(governanceJson, _governance(2));
    expect(issuerSnapshotJson, _originalIssuerEvidence);
    expect(jsonDecode(holderPublicJwkJson), containsPair('kty', 'EC'));
    presentationCompletions++;
    expect(sessionId, _preparedHandle);
    expect(remoteSignature, [4, 5, 6]);
    return FrbPresentationResponse(
      ok: !rejectPresentation,
      redirectUri: rejectPresentation ? null : 'https://verifier.example/done',
      errorDescription: rejectPresentation ? 'Verifier rejected proof' : null,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<void> storeIdentity([String id = 'stored-identity']) =>
      WalletCredentialStore.store(
        StoredCredential(
          id: id,
          format: 'dc+sd-jwt',
          issuer: 'untrusted-storage-label',
          types: const ['UntrustedStorageType'],
          rawJson: 'header.payload.signature~',
          issuedAt: DateTime.utc(2026, 10, 9),
        ),
      );
  Future<UserSelectionRequiredException> select(
    SpruceIdPlatformServiceExtended service,
  ) async {
    try {
      await service.initiateOID4VPRequestSDK(
        presentationRequest: _requestInput,
      );
    } on UserSelectionRequiredException catch (selection) {
      return selection;
    }
    throw StateError('Expected verified consent');
  }

  test(
    'explicit rejection retires native review handles without signing',
    () async {
      await storeIdentity();
      final bridge = _Bridge();
      final service = SpruceIdPlatformServiceExtended.withDependencies(
        bridge,
        _Holder.new,
      );
      final consent = await select(service);
      await service.cancelOID4VPRequestSDK(sessionId: consent.sessionId);
      expect(bridge.cancelled, containsAll(bridge.reviewed));
      await expectLater(
        service.completeOID4VPRequestSDK(
          sessionId: consent.sessionId,
          selectedCredentialId: 'stored-identity',
          selectedFields: ['credential/given_name'],
        ),
        throwsStateError,
      );
      expect(bridge.presentationPreparations, 0);
    },
  );

  test(
    'late rotated preparation handle is cancelled before any signing',
    () async {
      await storeIdentity();
      final gate = Completer<void>();
      final entered = Completer<void>();
      final bridge = _Bridge()
        ..prepareGate = gate
        ..prepareEntered = entered;
      final holders = <_Holder>[];
      final service = SpruceIdPlatformServiceExtended.withDependencies(
        bridge,
        () {
          final h = _Holder();
          holders.add(h);
          return h;
        },
      );
      final consent = await select(service);
      final completion = expectLater(
        service.completeOID4VPRequestSDK(
          sessionId: consent.sessionId,
          selectedCredentialId: 'stored-identity',
          selectedFields: ['credential/given_name'],
        ),
        throwsStateError,
      );
      await entered.future;
      await service.cancelOID4VPRequestSDK(sessionId: consent.sessionId);
      gate.complete();
      await completion;
      expect(bridge.cancelled, contains(_preparedHandle));
      expect(holders.fold<int>(0, (n, h) => n + h.signatures), 0);
      expect(holders.every((h) => h.closed), isTrue);
      expect(bridge.presentationCompletions, 0);
    },
  );

  test(
    'cancel during remote signing prevents completion after late signature',
    () async {
      await storeIdentity();
      final gate = Completer<void>();
      final entered = Completer<void>();
      final signer = _Holder()
        ..signatureGate = gate
        ..signatureEntered = entered;
      var calls = 0;
      final bridge = _Bridge();
      final service = SpruceIdPlatformServiceExtended.withDependencies(
        bridge,
        () => calls++ == 0 ? _Holder() : signer,
      );
      final consent = await select(service);
      final completion = expectLater(
        service.completeOID4VPRequestSDK(
          sessionId: consent.sessionId,
          selectedCredentialId: 'stored-identity',
          selectedFields: ['credential/given_name'],
        ),
        throwsStateError,
      );
      await entered.future;
      await service.cancelOID4VPRequestSDK(sessionId: consent.sessionId);
      gate.complete();
      await completion;
      expect(bridge.cancelled, contains(_preparedHandle));
      expect(bridge.presentationCompletions, 0);
      expect(signer.verifierReads, 1);
      expect(signer.closed, isTrue);
    },
  );

  test(
    'stale initiation result retires its new handle without cancelling newer consent',
    () async {
      await storeIdentity();
      final gate = Completer<void>();
      final entered = Completer<void>();
      final bridge = _Bridge()
        ..reviewGate = gate
        ..reviewEntered = entered;
      final service = SpruceIdPlatformServiceExtended.withDependencies(
        bridge,
        _Holder.new,
      );
      final first = expectLater(
        service.initiateOID4VPRequestSDK(presentationRequest: _requestInput),
        throwsStateError,
      );
      await entered.future;
      final second = await select(service);
      final newer = bridge.reviewed.last;
      gate.complete();
      await first;
      expect(bridge.cancelled, contains(bridge.reviewed.first));
      expect(bridge.cancelled, isNot(contains(newer)));
      await service.cancelOID4VPRequestSDK(sessionId: second.sessionId);
      expect(bridge.cancelled, containsAll(bridge.reviewed));
    },
  );

  test(
    'failed post-signing governance read retires prepared handle without submission',
    () async {
      await storeIdentity();
      var calls = 0;
      final signer = _Holder()..failVerifierRead = 2;
      final bridge = _Bridge();
      final service = SpruceIdPlatformServiceExtended.withDependencies(
        bridge,
        () => calls++ == 0 ? _Holder() : signer,
      );
      final consent = await select(service);
      await expectLater(
        service.completeOID4VPRequestSDK(
          sessionId: consent.sessionId,
          selectedCredentialId: 'stored-identity',
          selectedFields: ['credential/given_name'],
        ),
        throwsStateError,
      );
      expect(signer.signatures, 1);
      expect(signer.verifierReads, 2);
      expect(bridge.presentationCompletions, 0);
      expect(bridge.cancelled, contains(_preparedHandle));
    },
  );

  test(
    'native preparation failure consumes and cleans the reviewed choice',
    () async {
      await storeIdentity();
      final bridge = _Bridge()..rejectPrepare = true;
      final service = SpruceIdPlatformServiceExtended.withDependencies(
        bridge,
        _Holder.new,
      );
      final consent = await select(service);
      await expectLater(
        service.completeOID4VPRequestSDK(
          sessionId: consent.sessionId,
          selectedCredentialId: 'stored-identity',
          selectedFields: ['credential/given_name'],
        ),
        throwsStateError,
      );
      expect(bridge.cancelled, containsAll(bridge.reviewed));
      expect(bridge.presentationCompletions, 0);
    },
  );

  test('unselected native candidates are retired before preparation', () async {
    await storeIdentity();
    await storeIdentity('second-identity');
    final bridge = _Bridge();
    final service = SpruceIdPlatformServiceExtended.withDependencies(
      bridge,
      _Holder.new,
    );
    final consent = await select(service);
    await service.completeOID4VPRequestSDK(
      sessionId: consent.sessionId,
      selectedCredentialId: 'stored-identity',
      selectedFields: ['credential/given_name'],
    );
    final preparedEvent = bridge.events.firstWhere(
      (e) => e.startsWith('prepare:'),
    );
    final selected = preparedEvent.substring('prepare:'.length);
    final other = bridge.reviewed.singleWhere((h) => h != selected);
    expect(
      bridge.events.indexOf('cancel:$other'),
      lessThan(bridge.events.indexOf(preparedEvent)),
    );
    expect(bridge.cancelled, contains(other));
    // The selected review handle was consumed by native preparation; cleanup
    // retires its replacement rather than calling cancellation on the old ID.
    expect(bridge.cancelled, contains(_preparedHandle));
  });

  test(
    'inline, duplicate and alternate QR authority parameters cannot select governance',
    () async {
      await storeIdentity();
      final bridge = _Bridge();
      final holders = <_Holder>[];
      final service = SpruceIdPlatformServiceExtended.withDependencies(
        bridge,
        () {
          final h = _Holder();
          holders.add(h);
          return h;
        },
      );
      for (final input in [
        'openid4vp://authorize?request=inline-jws',
        '$_requestInput&client_id=another-client',
        '$_requestInput&client%5fid=encoded-duplicate',
        '$_requestInput&request_uri_method=post',
        '$_requestInput&response_uri=https://attacker.example',
        '$_requestInput#fragment',
      ]) {
        await expectLater(
          service.initiateOID4VPRequestSDK(presentationRequest: input),
          throwsStateError,
        );
      }
      expect(holders.every((h) => h.verifierReads == 0 && h.closed), isTrue);
      expect(bridge.credentialReviews, 0);
      expect(bridge.presentationPreparations, 0);
    },
  );

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
    final holder = _Holder();
    final service = SpruceIdPlatformServiceExtended.withDependencies(
      bridge,
      () => holder,
    );
    final result = await service.handleOID4VCOfferSDK(
      credentialOffer: 'openid-credential-offer://approved',
    );
    final stored = await WalletCredentialStore.getAll();
    expect(result['id'], stored.single.id);
    expect(stored.single.rawJson, 'header.payload.signature~');
    expect(stored.single.issuer, 'https://issuer.example');
    expect(bridge.receiptCompletions, 1);
    expect(bridge.receiptFinalizations, 1);
    expect(holder.issuerReads, 3);
    expect(bridge.events, [
      'receipt:prepare',
      'receipt:request',
      'receipt:finalize',
    ]);
  });

  test(
    'authority lost after the response prevents finalization and storage',
    () async {
      final bridge = _Bridge();
      final holder = _Holder()..failIssuerRead = 3;
      final service = SpruceIdPlatformServiceExtended.withDependencies(
        bridge,
        () => holder,
      );
      await expectLater(
        service.handleOID4VCOfferSDK(
          credentialOffer: 'openid-credential-offer://approved',
        ),
        throwsStateError,
      );
      expect(bridge.receiptCompletions, 1);
      expect(bridge.receiptFinalizations, 0);
      expect(await WalletCredentialStore.getAll(), isEmpty);
      expect(holder.closed, isTrue);
    },
  );

  test(
    'native finalization rejection never stores a received credential',
    () async {
      final bridge = _Bridge()..rejectFinalization = true;
      final service = SpruceIdPlatformServiceExtended.withDependencies(
        bridge,
        _Holder.new,
      );
      await expectLater(
        service.handleOID4VCOfferSDK(
          credentialOffer: 'openid-credential-offer://approved',
        ),
        throwsStateError,
      );
      expect(bridge.receiptFinalizations, 1);
      expect(await WalletCredentialStore.getAll(), isEmpty);
    },
  );

  test(
    'missing initial authority prevents preparing or signing an offer',
    () async {
      final bridge = _Bridge();
      final holder = _Holder()..failIssuerRead = 1;
      final service = SpruceIdPlatformServiceExtended.withDependencies(
        bridge,
        () => holder,
      );
      await expectLater(
        service.handleOID4VCOfferSDK(
          credentialOffer: 'openid-credential-offer://approved',
        ),
        throwsStateError,
      );
      expect(bridge.events, isEmpty);
      expect(holder.signatures, 0);
      expect(await WalletCredentialStore.getAll(), isEmpty);
    },
  );

  test(
    'unrecognized native routes and malformed requests never reach signing',
    () async {
      await storeIdentity();
      FrbPresentationRequest request({
        String digest = 'bound-request-digest',
        String queryType = 'dcql_query',
        String? dcql,
        String? definition,
      }) => FrbPresentationRequest(
        clientId: _clientId,
        nonce: 'request-nonce',
        responseUri: 'https://verifier.example/response',
        requestDigest: digest,
        queryType: queryType,
        dcqlQueryJson: dcql,
        presentationDefinitionJson: definition,
      );

      final bridge = _Bridge();
      final service = SpruceIdPlatformServiceExtended.withDependencies(
        bridge,
        _Holder.new,
      );
      final cases = [
        (route: 'unknown', parsed: null),
        (route: 'oid4vp', parsed: request(digest: '')),
        (route: 'oid4vp', parsed: request(dcql: '{}')),
        (route: 'oid4vp', parsed: request(queryType: 'unknown')),
        (
          route: 'oid4vp',
          parsed: request(
            queryType: 'presentation_definition',
            definition: '{}',
          ),
        ),
        (
          route: 'oid4vp',
          parsed: request(
            queryType: 'presentation_definition',
            definition: jsonEncode({
              'input_descriptors': [{}],
            }),
          ),
        ),
        (
          route: 'oid4vp',
          parsed: request(
            queryType: 'presentation_definition',
            definition: jsonEncode({
              'input_descriptors': [
                {
                  'id': 'identity-query',
                  'format': {'unsupported': {}},
                },
              ],
            }),
          ),
        ),
        (
          route: 'oid4vp',
          parsed: request(
            queryType: 'presentation_definition',
            definition: jsonEncode({
              'input_descriptors': [
                {'id': 'identity-query'},
              ],
            }),
          ),
        ),
      ];
      for (final input in cases) {
        bridge.presentationRoute = input.route;
        bridge.requestOverride = input.parsed;
        await expectLater(
          service.initiateOID4VPRequestSDK(presentationRequest: _requestInput),
          throwsStateError,
        );
      }
      expect(bridge.presentationPreparations, 0);
      expect(bridge.presentationCompletions, 0);
    },
  );

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
      service.initiateOID4VPRequestSDK(presentationRequest: _requestInput),
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
          presentationRequest: _requestInput,
        );
      } on UserSelectionRequiredException catch (selection) {
        return selection;
      }
      throw StateError('A credential selection was required');
    }

    final first = await initiate();
    expect(first.matches.single['id'], 'stored-identity');
    expect(bridge.credentialReviews, 1);
    expect(first.matches.single['issuer'], 'https://issuer.example');
    expect(first.matches.single['type'], 'ExampleIdentity');
    expect(
      first.matches.single['alwaysSharedClaims'],
      containsPair('sub', '"holder-identifier"'),
    );
    expect(first.requestDetails['verifier'], _clientId);
    bridge.rejectReview = true;
    await expectLater(
      service.initiateOID4VPRequestSDK(presentationRequest: _requestInput),
      throwsStateError,
    );
    expect(bridge.presentationPreparations, 0);
    bridge.rejectReview = false;
    bridge.reviewResponseOverride = jsonEncode({
      'issuer': 'https://issuer.example',
      'credential_type': 'ExampleIdentity',
      'format': 'dc+sd-jwt',
      'always_shared': {'sub': 9},
      'protected_header': {'alg': '"ES256"'},
    });
    await expectLater(
      service.initiateOID4VPRequestSDK(presentationRequest: _requestInput),
      throwsStateError,
    );
    bridge.reviewResponseOverride = null;
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
    await expectLater(
      service.completeOID4VPRequestSDK(
        sessionId: fourth.sessionId,
        selectedCredentialId: 'stored-identity',
        selectedFields: const ['unbound/given_name'],
      ),
      throwsStateError,
    );
    expect(bridge.presentationPreparations, 0);

    final fifth = await initiate();
    // Approval retains the exact reviewed token, even if storage changes.
    await WalletCredentialStore.delete('stored-identity');
    final result = await service.completeOID4VPRequestSDK(
      sessionId: fifth.sessionId,
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

  for (final invalidFirst in [true, false]) {
    test(
      'invalid candidate does not suppress verified consent (invalidFirst=$invalidFirst)',
      () async {
        for (final valid in [true, false]) {
          await WalletCredentialStore.store(
            StoredCredential(
              id: valid ? 'stored-identity' : 'untrusted-entry',
              format: 'dc+sd-jwt',
              issuer: 'unverified-storage-label',
              types: const ['UnverifiedStorageType'],
              rawJson: valid
                  ? 'header.payload.signature~'
                  : 'rejected.credential.signature~',
              issuedAt: DateTime.utc(2026, 10, valid == invalidFirst ? 10 : 9),
            ),
          );
        }
        final bridge = _Bridge()
          ..rejectedCredentials.add('rejected.credential.signature~');
        final service = SpruceIdPlatformServiceExtended.withDependencies(
          bridge,
          _Holder.new,
        );
        UserSelectionRequiredException? review;
        try {
          await service.initiateOID4VPRequestSDK(
            presentationRequest: _requestInput,
          );
        } on UserSelectionRequiredException catch (value) {
          review = value;
        }
        expect(review, isNotNull);
        expect(bridge.credentialReviews, 2);
        expect(review!.matches, hasLength(1));
        expect(review.matches.single['id'], 'stored-identity');
        expect(review.matches.single['issuer'], 'https://issuer.example');
        expect(
          review.matches.single['alwaysSharedClaims'],
          containsPair('sub', '"holder-identifier"'),
        );
        expect(
          await WalletCredentialStore.getAll(),
          hasLength(2),
          reason: 'rejected entries remain stored',
        );
        expect(bridge.presentationPreparations, 0);
      },
    );
  }

  test('bounded approval sessions evict the oldest unused request', () async {
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
    final sessions = <String>[];
    for (var index = 0; index < 17; index++) {
      try {
        await service.initiateOID4VPRequestSDK(
          presentationRequest: _requestInput,
        );
        fail('Credential selection should be required');
      } on UserSelectionRequiredException catch (selection) {
        sessions.add(selection.sessionId);
      }
    }
    expect(sessions.toSet(), hasLength(17));
    await expectLater(
      service.completeOID4VPRequestSDK(
        sessionId: sessions.first,
        selectedCredentialId: 'stored-identity',
        selectedFields: const ['credential/given_name'],
      ),
      throwsStateError,
    );
    expect(bridge.presentationPreparations, 0);
    expect(
      await service.completeOID4VPRequestSDK(
        sessionId: sessions.last,
        selectedCredentialId: 'stored-identity',
        selectedFields: const ['credential/given_name'],
      ),
      {'ok': true, 'redirect_uri': 'https://verifier.example/done'},
    );
    expect(bridge.presentationPreparations, 1);
  });

  test(
    'unsupported presentation definitions stop before remote signing',
    () async {
      await storeIdentity();
      final bridge = _Bridge();
      final service = SpruceIdPlatformServiceExtended.withDependencies(
        bridge,
        _Holder.new,
      );
      for (final fields in [
        [
          {
            'path': [r'$.given_name'],
            'filter': {'const': 'Alice'},
          },
        ],
        [
          {
            'path': [r'$.given_name'],
          },
          {
            'path': [r'$.given_name'],
          },
        ],
        [
          {
            'path': [r'$..private_key'],
          },
        ],
      ]) {
        bridge.requestOverride = FrbPresentationRequest(
          clientId: _clientId,
          nonce: 'request-nonce',
          responseUri: 'https://verifier.example/response',
          requestDigest: 'bound-request-digest',
          queryType: 'presentation_definition',
          presentationDefinitionJson: jsonEncode({
            'input_descriptors': [
              {
                'id': 'definition-identity',
                'format': {
                  'dc+sd-jwt': {
                    'alg': ['ES256'],
                  },
                },
                'constraints': {'fields': fields},
              },
            ],
          }),
        );
        await expectLater(
          service.initiateOID4VPRequestSDK(presentationRequest: _requestInput),
          throwsStateError,
        );
      }
      expect(bridge.presentationPreparations, 0);
    },
  );

  test('malformed DCQL approval never reaches remote signing', () async {
    await storeIdentity();
    final bridge = _Bridge();
    final service = SpruceIdPlatformServiceExtended.withDependencies(
      bridge,
      _Holder.new,
    );
    for (final credential in [
      {'id': 'identity-query', 'format': 'mso_mdoc'},
      {
        'id': 'identity-query',
        'format': 'dc+sd-jwt',
        'claims': [
          {
            'path': ['given_name'],
          },
          {
            'path': ['given_name'],
          },
        ],
      },
      {
        'id': 'identity-query',
        'format': 'dc+sd-jwt',
        'claims': [
          {
            'path': ['nested', 'private'],
          },
        ],
      },
    ]) {
      bridge.requestOverride = FrbPresentationRequest(
        clientId: _clientId,
        nonce: 'request-nonce',
        responseUri: 'https://verifier.example/response',
        requestDigest: 'bound-request-digest',
        queryType: 'dcql_query',
        dcqlQueryJson: jsonEncode({
          'credentials': [credential],
        }),
      );
      await expectLater(
        service.initiateOID4VPRequestSDK(presentationRequest: _requestInput),
        throwsStateError,
      );
    }
    expect(bridge.presentationPreparations, 0);
  });

  test(
    'verifier rejection remains failure and consumes the approval',
    () async {
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
      final bridge = _Bridge()..rejectPresentation = true;
      final holders = <_Holder>[];
      final service = SpruceIdPlatformServiceExtended.withDependencies(
        bridge,
        () {
          final holder = _Holder();
          holders.add(holder);
          return holder;
        },
      );
      late UserSelectionRequiredException selection;
      try {
        await service.initiateOID4VPRequestSDK(
          presentationRequest: _requestInput,
        );
        fail('Credential selection should be required');
      } on UserSelectionRequiredException catch (error) {
        selection = error;
      }

      await expectLater(
        service.completeOID4VPRequestSDK(
          sessionId: selection.sessionId,
          selectedCredentialId: 'stored-identity',
          selectedFields: const ['credential/given_name'],
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'Verifier rejected proof',
          ),
        ),
      );
      await expectLater(
        service.completeOID4VPRequestSDK(
          sessionId: selection.sessionId,
          selectedCredentialId: 'stored-identity',
          selectedFields: const ['credential/given_name'],
        ),
        throwsStateError,
      );
      expect(bridge.presentationCompletions, 1);
      expect(holders.every((holder) => holder.closed), isTrue);
    },
  );
}
