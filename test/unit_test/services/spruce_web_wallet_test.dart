import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/services/spruce_platform_service_web.dart';
import 'package:marty_authenticator/services/wasm/marty_wasm_stub.dart';
import 'package:marty_authenticator/spruce_client.dart';

void main() {
  test(
    'session wallet preserves credentials, filters scalar/list types and deletes by id',
    () async {
      final service = SpruceIdPlatformServiceWeb();
      final wallet = SpruceIdWalletManager(service);
      final ob3 = <String, dynamic>{
        'id': 'badge-1',
        'type': ['VerifiableCredential', 'OpenBadgeCredential'],
        'proof': {'proofValue': 'unchanged'},
      };
      final degree = <String, dynamic>{
        'id': 'degree-1',
        'type': 'UniversityDegree',
      };
      final other = <String, dynamic>{'id': 'other-1'};
      expect(await wallet.getAllCredentials(), isEmpty);
      for (final credential in [ob3, degree, other]) {
        await wallet.storeCredential(credential);
      }
      expect(await wallet.getCredentialsByType('OpenBadgeCredential'), [ob3]);
      expect(await wallet.getCredentialsByType('UniversityDegree'), [degree]);
      expect(await wallet.getCredentialsByType('unknown'), isEmpty);
      final snapshot = await wallet.getAllCredentials();
      snapshot.clear();
      expect(await wallet.getAllCredentials(), [ob3, degree, other]);
      await wallet.deleteCredential('badge-1');
      await wallet.deleteCredential('missing');
      expect(await wallet.getAllCredentials(), [degree, other]);
      expect(ob3['proof'], {'proofValue': 'unchanged'});
      expect(
        await SpruceIdPlatformServiceWeb().getStoredCredentials(),
        isEmpty,
        reason: 'Independent sessions must not share wallet contents',
      );
    },
  );

  test(
    'desktop initialization is idempotent but never advertises WASM availability',
    () async {
      final service = SpruceIdPlatformServiceWeb();
      expect(service.isInitialized, isFalse);
      await service.initializeW3C();
      await service.initializeW3C();
      expect(service.isInitialized, isTrue);
      expect(MartyWasm.instance.isAvailable, isFalse);
      expect(MartyWasm.instance, same(MartyWasm.instance));
    },
  );

  final unavailable =
      <String, Future<dynamic> Function(SpruceIdPlatformServiceWeb)>{
        'DID resolution': (s) => s.resolveDid('did:web:issuer.test'),
        'managed credential signing': (s) =>
            s.signVerifiableCredential({'id': 'vc'}, keyId: 'key-7'),
        'credential verification': (s) =>
            s.verifyVerifiableCredential({'id': 'vc'}),
        'certificate request': (s) => s.createCSR('CN=Example', keyId: 'key-7'),
        'certificate signing': (s) =>
            s.signWithCertificate({'id': 'vc'}, 'cert-7'),
        'certificate chain verification': (s) =>
            s.verifyCertificateChain(['leaf']),
        'JWT creation': (s) =>
            s.createJWT('https://issuer.test', {'sub': 'holder'}),
        'SD-JWT creation': (s) =>
            s.createSdJwt('https://issuer.test', {'age': 25}, ['age']),
        'mobile document initialization': (s) =>
            s.initializeMdl({'docType': 'org.iso.18013.5.1.mDL'}),
        'age presentation': (s) => s.presentForAgeVerification(18),
        'document presentation': (s) =>
            s.createMdocResponse(['given_name'], ['birth_date']),
        'unsupported DID method': (s) => s.createDid(method: 'web'),
        'unsupported key type': (s) => s.generateKeyPair(),
      };
  for (final entry in unavailable.entries) {
    test('web service rejects unavailable ${entry.key}', () async {
      await expectLater(
        entry.value(SpruceIdPlatformServiceWeb()),
        throwsA(isA<UnimplementedError>()),
      );
    });
  }

  final nativeOnly =
      <String, Future<dynamic> Function(SpruceIdPlatformServiceWeb)>{
        'Ed25519 DID generation': (s) => s.createDid(),
        'P-256 DID generation': (s) => s.createDid(method: 'jwk'),
        'EC key generation': (s) => s.generateKeyPair(keyType: 'EC'),
        'JWT verification': (s) =>
            s.verifyJWT('signed.jwt.token', 'https://issuer.test'),
        'SD-JWT verification': (s) =>
            s.verifySdJwt('signed.jwt.token~disclosure~', ['age']),
      };
  for (final entry in nativeOnly.entries) {
    test(
      'non-web runtime does not substitute crypto for ${entry.key}',
      () async {
        await expectLater(
          entry.value(SpruceIdPlatformServiceWeb()),
          throwsA(isA<UnsupportedError>()),
        );
      },
    );
  }

  test(
    'WASM stub result records retain data but cannot serialize a usable key',
    () {
      final key = WasmKeyResult(
        did: 'did:key:fixture',
        jwk: {'kty': 'OKP'},
        keyId: 'key-7',
      );
      expect(key.did, 'did:key:fixture');
      expect(key.keyId, 'key-7');
      expect(key.jwk, {'kty': 'OKP'});
      expect(() => key.jwkJson, throwsA(isA<UnimplementedError>()));
      final credential = WasmCredentialResult(
        jwt: 'fixture.jwt',
        credentialId: 'vc-7',
      );
      expect(credential.jwt, 'fixture.jwt');
      expect(credential.credentialId, 'vc-7');
      final result = WasmVerifyResult(
        valid: false,
        payload: {'sub': 'holder'},
        error: 'unsupported',
      );
      expect(result.valid, isFalse);
      expect(result.payload, {'sub': 'holder'});
      expect(result.error, 'unsupported');
    },
  );

  test(
    'WASM stub rejects issuance and presentation instead of returning artifacts',
    () async {
      final wasm = MartyWasm.instance;
      final operations = <Future<dynamic> Function()>[
        () => wasm.createVerifiableCredential(
          issuerDid: 'did:example:issuer',
          issuerJwkJson: '{}',
          credentialType: 'OpenBadgeCredential',
          claims: {'name': 'Course'},
        ),
        () => wasm.createCredentialOffer(
          issuerUrl: 'https://issuer.test',
          credentialTypes: ['OpenBadgeCredential'],
        ),
        () => wasm.issueOpenBadgeV3(request: {'id': 'badge-1'}),
        () => wasm.verifyOpenBadgeV3(request: {'id': 'badge-1'}),
        () => wasm.createPresentation(
          holderDid: 'did:example:holder',
          holderJwkJson: '{}',
          credentialJwts: ['signed.jwt'],
          audience: 'https://verifier.test',
        ),
        () => wasm.createAuthorizationResponse(
          vpToken: 'vp-token',
          presentationSubmission: {'id': 'submission-1'},
        ),
        () => wasm.extractCredentialsFromVp('signed.vp'),
      ];
      for (final operation in operations) {
        await expectLater(operation(), throwsA(isA<UnsupportedError>()));
      }
      expect(
        () => wasm.generateOfferUri(
          issuerUrl: 'https://issuer.test',
          offerId: 'offer-1',
        ),
        throwsA(isA<UnsupportedError>()),
      );
      expect(wasm.getVersion, throwsA(isA<UnsupportedError>()));
      expect(wasm.healthCheck, throwsA(isA<UnsupportedError>()));
    },
  );
}
