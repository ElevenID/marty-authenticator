import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/model/promotional_credential.dart';
import 'package:marty_authenticator/models/credential.dart';
import 'package:marty_authenticator/models/credential_group.dart';
import 'package:marty_authenticator/models/mdoc_credential.dart';
import 'package:marty_authenticator/models/selectable_credential.dart';
import 'package:marty_authenticator/models/verifiable_credential.dart';
import 'package:marty_authenticator/services/status_list_service.dart';

const _trust = TrustInfo(
  isValid: true,
  trustAnchor: 'Example authority',
  statusMessage: 'Verified',
  certificateChain: ['leaf-pem', 'root-pem'],
);

VerifiableCredential _vc({
  Map<String, dynamic> subject = const {'name': 'Ada', 'age': 25},
  Object? issuer = 'did:web:example.test',
  List<String> types = const ['VerifiableCredential', 'OpenBadgeCredential'],
  String? expires,
  Object? status,
  bool signed = true,
}) => VerifiableCredential.fromJson({
  'id': 'urn:credential:one',
  'type': types,
  'issuer': issuer,
  'credentialSubject': subject,
  'issuanceDate': '2026-01-01T00:00:00.000Z',
  'expirationDate': ?expires,
  if (signed) 'proof': {'type': 'DataIntegrityProof', 'proofValue': 'fixture'},
  'credentialStatus': ?status,
});

MDocCredential _mdoc({
  Map<String, dynamic> claims = const {
    'given_name': 'Ada',
    'family_name': 'Lovelace',
  },
  String type = 'org.iso.18013.5.1.mDL',
  DateTime? expires,
  TrustInfo? trust,
}) => MDocCredential(
  id: 'urn:mdoc:one',
  docType: type,
  issuerSigned: {
    'nameSpaces': {'org.iso.18013.5.1': claims},
  },
  deviceSigned: {'deviceAuth': 'fixture'},
  expiryDate: expires,
  trustInfo: trust,
);

class _StatusService implements StatusListService {
  int checks = 0;
  Object? lastStatus;
  StatusCheckResult result = StatusCheckResult.success(isRevoked: true);

  @override
  Future<StatusCheckResult> checkCredentialStatus(Object? status) async {
    checks++;
    lastStatus = status;
    return result;
  }

  @override
  Future<bool?> checkRevocationStatus(Object? status) async {
    lastStatus = status;
    return result.isRevoked;
  }

  @override
  Future<bool?> checkSuspensionStatus(Object? status) async {
    lastStatus = status;
    return result.isSuspended;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('stored verifiable credential', () {
    test('round trip preserves signed payload, trust and status entries', () {
      final statuses = <dynamic>[
        {'statusPurpose': 'revocation', 'statusListIndex': '4'},
        {'statusPurpose': 'suspension', 'statusListIndex': '7'},
        'unknown entry',
      ];
      final credential = VerifiableCredential.fromJson({
        ..._vc(status: statuses).toJson(),
        '@context': ['https://www.w3.org/ns/credentials/v2'],
        'trustInfo': _trust.toJson(),
        '_rawJson': '{"signed":"payload"}',
      });
      statuses.first['statusPurpose'] = 'changed';
      expect(credential.supportsRevocation, isTrue);
      expect(credential.supportsSuspension, isTrue);
      expect(credential.hasStatusEntry, isTrue);
      expect(credential.rawJson, '{"signed":"payload"}');
      expect(credential.context, ['https://www.w3.org/ns/credentials/v2']);
      final restored = VerifiableCredential.fromJson(credential.toJson());
      expect(restored.toJson(), credential.toJson());
      expect(restored.trustInfo!.certificateChain, ['leaf-pem', 'root-pem']);
      final updated = credential.copyWithTrustInfo(
        const TrustInfo(isValid: false),
      );
      expect(updated.trustInfo!.isValid, isFalse);
      expect(updated.id, credential.id);
      expect(updated.proof, credential.proof);
      expect(updated.rawJson, credential.rawJson);
      expect(updated.credentialStatus, credential.credentialStatus);
    });

    test('missing optional fields and scalar context stay representable', () {
      final empty = VerifiableCredential.fromJson({});
      expect(empty.id, isEmpty);
      expect(empty.types, ['VerifiableCredential']);
      expect(empty.issuerId, isEmpty);
      expect(empty.issuerName, 'Unknown Issuer');
      expect(empty.displayName, 'Credential');
      expect(empty.context, isNull);
      expect(empty.hasStatusEntry, isFalse);
      expect(empty.supportsRevocation, isFalse);
      expect(empty.supportsSuspension, isFalse);
      expect(empty.toJson(), isNot(contains('proof')));
      expect(empty.toJson(), isNot(contains('expirationDate')));
      expect(VerifiableCredential.fromJson({'@context': 'context'}).context, [
        'context',
      ]);
      expect(
        VerifiableCredential.fromJson({
          'credentialStatus': 'opaque',
        }).credentialStatus,
        'opaque',
      );
      expect(TrustInfo.fromJson({}).isValid, isFalse);
      expect(TrustInfo.fromJson({}).certificateChain, isEmpty);
    });

    test('display labels honor issuer name and subject fallbacks', () {
      expect(
        _vc(
          issuer: {'id': 'https://issuer.test', 'name': 'Academy'},
        ).issuerName,
        'Academy',
      );
      expect(_vc().issuerName, 'example');
      expect(_vc(issuer: 'did:key:zExample').issuerName, 'key');
      expect(_vc(issuer: 'https://issuer.test').issuerName, 'Unknown Issuer');
      expect(_vc().displayName, 'Ada');
      expect(_vc(subject: {'given_name': 'Grace'}).displayName, 'Grace');
      expect(
        _vc(subject: {'id': 'did:example:holder'}).displayName,
        'did:example:holder',
      );
      expect(_vc(subject: {}).displayName, 'Open Badge');
      expect(
        _vc(
          types: ['VerifiableCredential', 'AchievementCredential'],
        ).credentialType,
        'Open Badge',
      );
      expect(
        _vc(types: ['VerifiableCredential', 'UniversityDegree']).credentialType,
        'UniversityDegree',
      );
      expect(_vc().claims, {'name': 'Ada', 'age': 25});
    });

    test(
      'expiry takes precedence over proof and malformed expiry is tolerated',
      () {
        final past = DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String();
        final future = DateTime.now()
            .add(const Duration(days: 365))
            .toIso8601String();
        expect(_vc(expires: past).status, CredentialStatus.expired);
        expect(_vc(expires: past).isValid, isFalse);
        expect(_vc(signed: false).status, CredentialStatus.invalid);
        expect(_vc(expires: future).status, CredentialStatus.valid);
        expect(_vc(expires: 'invalid-date').isExpired, isFalse);
        expect(_vc(expires: 'invalid-date').isValid, isTrue);
      },
    );

    test(
      'status caching avoids duplicate checks and can be invalidated',
      () async {
        final status = {'statusPurpose': 'revocation', 'statusListIndex': '4'};
        final credential = _vc(status: status);
        final service = _StatusService();
        expect(credential.supportsRevocation, isTrue);
        expect(credential.supportsSuspension, isFalse);
        expect(credential.getStatusWithRevocation(), CredentialStatus.valid);
        final first = await credential.checkStatus(service);
        expect(await credential.checkStatus(service), same(first));
        expect(service.checks, 1);
        expect(service.lastStatus, status);
        expect(credential.getStatusWithRevocation(), CredentialStatus.revoked);
        expect(await credential.checkRevocationStatus(service), isTrue);
        service.result = StatusCheckResult.success(
          isRevoked: false,
          isSuspended: true,
        );
        expect(await credential.checkSuspensionStatus(service), isTrue);
        credential.clearStatusCache();
        await credential.checkStatus(service);
        expect(service.checks, 2);
        expect(credential.getStatusWithRevocation(), CredentialStatus.valid);
        service.result = StatusCheckResult.failure('offline');
        credential.clearStatusCache();
        expect((await credential.checkStatus(service)).success, isFalse);
        expect(credential.getStatusWithRevocation(), CredentialStatus.valid);
        expect(await _vc().checkRevocationStatus(service), isNull);
        expect(await _vc().checkSuspensionStatus(service), isNull);
        expect(
          _vc(signed: false).getStatusWithRevocation(),
          CredentialStatus.invalid,
        );
        expect(
          _vc(expires: '2000-01-01T00:00:00Z').getStatusWithRevocation(),
          CredentialStatus.expired,
        );
        expect(
          CachedStatusCheck(result: first, cachedAt: DateTime.now()).isExpired,
          isFalse,
        );
        expect(
          CachedStatusCheck(
            result: first,
            cachedAt: DateTime.now().subtract(const Duration(minutes: 6)),
          ).isExpired,
          isTrue,
        );
      },
    );
  });

  group('mobile documents', () {
    test('map and issuer item namespaces yield holder claims consistently', () {
      final claims = <String, dynamic>{
        'given_name': 'Ada',
        'family_name': 'Lovelace',
        'issuing_authority': 'DMV',
        'issuing_country': 'GB',
        'document_number': 'D123',
        'age_over_18': true,
        'age_over_65': false,
        'birth_date': '${DateTime.now().year - 25}-01-01',
      };
      final map = _mdoc(claims: claims);
      final list = MDocCredential.fromCbor({
        'id': 'urn:mdoc:list',
        'issuerSigned': {
          'nameSpaces': {
            'org.iso.18013.5.1': [
              for (final entry in claims.entries)
                {'elementIdentifier': entry.key, 'elementValue': entry.value},
              {'elementValue': 'ignored without identifier'},
              'ignored non-map',
            ],
          },
        },
      });
      for (final document in [map, list]) {
        expect(document.holderName, 'Ada Lovelace');
        expect(document.issuerId, 'DMV');
        expect(document.issuerName, 'DMV');
        expect(document.issuingCountry, 'GB');
        expect(document.documentNumber, 'D123');
        expect(document.age, 25);
        expect(document.isAgeOver(18), isTrue);
        expect(document.isAgeOver(65), isFalse);
        expect(document.isAgeOver(21), isNull);
        expect(document.claims, claims);
      }
    });

    test(
      'missing namespaces, malformed dates and document types have safe labels',
      () {
        final empty = MDocCredential.fromJson({});
        expect(empty.id, startsWith('mdoc_'));
        expect(empty.types, ['org.iso.18013.5.1.mDL']);
        expect(empty.displayName, 'Mobile Driving License');
        expect(empty.holderName, 'Document Holder');
        expect(empty.issuingAuthority, 'Issuing Authority');
        expect(empty.issuingCountry, 'Unknown');
        expect(empty.documentNumber, '••••••••');
        expect(empty.claims, isEmpty);
        expect(empty.age, isNull);
        expect(empty.issuanceDate, isEmpty);
        expect(empty.expirationDate, isNull);
        expect(
          _mdoc(claims: {'family_name': 'Lovelace'}).holderName,
          'Lovelace',
        );
        expect(_mdoc(claims: {'given_name': 'Ada'}).holderName, 'Ada');
        expect(_mdoc(claims: {'birth_date': 'invalid'}).age, isNull);
        final birthdayLater = _mdoc(
          claims: {'birth_date': '${DateTime.now().year - 25}-12-31'},
        );
        expect(
          birthdayLater.age,
          DateTime.now().month == 12 && DateTime.now().day == 31 ? 25 : 24,
        );
        expect(_mdoc(type: 'org.iso.18013.5.1.mID').documentType, 'Mobile ID');
        expect(
          _mdoc(type: 'org.iso.18013.5.1.mPassport').documentType,
          'Mobile Passport',
        );
        expect(_mdoc(type: 'custom').documentType, 'Mobile Document');
        final otherNamespace = MDocCredential.fromJson({
          'issuerSigned': {
            'nameSpaces': {
              'other': {'x': 1},
            },
          },
        });
        expect(otherNamespace.holderName, 'Document Holder');
        expect(otherNamespace.claims, {'x': 1});
      },
    );

    test('round trip and trust update preserve document bytes and dates', () {
      final document = MDocCredential.fromJson({
        ..._mdoc().toJson(),
        'portrait': 'portrait-base64',
        'signature_usual_mark': 'signature-base64',
        'issue_date': '2026-01-01T00:00:00.000Z',
        'expiry_date': '2099-01-01T00:00:00.000Z',
        'trustInfo': _trust.toJson(),
      });
      expect(document.issuanceDate, '2026-01-01T00:00:00.000Z');
      expect(document.expirationDate, '2099-01-01T00:00:00.000Z');
      expect(
        MDocCredential.fromJson(document.toJson()).toJson(),
        document.toJson(),
      );
      final rejected = document.copyWithTrustInfo(
        const TrustInfo(isValid: false),
      );
      expect(document.status, CredentialStatus.valid);
      expect(document.isValid, isTrue);
      expect(rejected.status, CredentialStatus.invalid);
      expect(rejected.isValid, isFalse);
      expect(rejected.portrait, document.portrait);
      expect(rejected.deviceSigned, document.deviceSigned);
      expect(rejected.id, document.id);
      final expired = _mdoc(expires: DateTime(2000), trust: _trust);
      expect(expired.isValid, isFalse);
      expect(expired.status, CredentialStatus.expired);
      expect(_mdoc().isValid, isTrue);
    });
  });

  test(
    'disclosure starts minimal, preserves required fields and tracks changes',
    () {
      final initial = SelectableCredential.fromVerifiableCredential(
        _vc(),
        requiredAttributes: ['name', 'missing'],
        optionalAttributes: ['age'],
      );
      expect(initial.id, 'urn:credential:one');
      expect(initial.name, 'Ada');
      expect(initial.type, 'Open Badge');
      expect(initial.issuer, 'example');
      expect(initial.isSelected, isFalse);
      expect(initial.privacyLevel, PrivacyLevel.minimal);
      expect(initial.disclosedAttributes, ['name']);
      expect(initial.hasAllRequiredAttributes, isFalse);
      expect(initial.privacyScore, 0.5);
      final changed = initial.copyWith(
        isSelected: true,
        privacyLevel: PrivacyLevel.moderate,
        attributeSelections: {'name': true, 'age': false, 'missing': true},
      );
      expect(changed.hiddenAttributes, ['age']);
      expect(changed.hasAllRequiredAttributes, isTrue);
      expect(changed.isSelected, isTrue);
      expect(changed.optionalAttributes, ['age']);
      expect(
        changed.copyWith().attributeSelections,
        changed.attributeSelections,
      );
      expect(initial.disclosedAttributes, ['name']);
      final mdl = SelectableCredential.fromMDocCredential(
        _mdoc(),
        requiredAttributes: ['given_name', 'missing'],
        optionalAttributes: ['family_name'],
      );
      expect(mdl.type, 'org.iso.18013.5.1.mDL');
      expect(mdl.disclosedAttributes, ['given_name']);
      expect(mdl.hasAllRequiredAttributes, isFalse);
      expect(
        SelectableCredential.fromVerifiableCredential(
          _vc(subject: {}),
        ).privacyScore,
        1,
      );
      expect(PrivacyLevel.values.map((level) => level.color), [
        Colors.green,
        Colors.orange,
        Colors.red,
      ]);
      expect(PrivacyLevel.full.description, 'Full disclosure');
    },
  );

  test(
    'wallet groups preserve mixed ordering and recognize holder documents',
    () {
      const empty = CredentialGroup(issuerName: 'Academy');
      expect(empty.isEmpty, isTrue);
      expect(empty.primaryCredential, isNull);
      expect(empty.hasMultiple, isFalse);
      final vc = _vc();
      final mdl = _mdoc();
      final promo = DefaultPromotionalCredentials.all.first;
      final vcGroup = empty.copyWith(verifiableCredentials: [vc]);
      expect(vcGroup.hasSingle, isTrue);
      expect(vcGroup.primaryCredential, same(vc));
      final mdlGroup = empty.copyWith(mDocCredentials: [mdl]);
      expect(mdlGroup.primaryCredential, same(mdl));
      expect(mdlGroup.hasHolderDocuments, isTrue);
      for (final type in [
        'org.iso.18013.5.1.mID',
        'org.iso.18013.5.1.mPassport',
      ]) {
        expect(
          empty
              .copyWith(mDocCredentials: [_mdoc(type: type)])
              .hasHolderDocuments,
          isTrue,
        );
      }
      expect(
        empty
            .copyWith(mDocCredentials: [_mdoc(type: 'custom')])
            .hasHolderDocuments,
        isFalse,
      );
      final combined = vcGroup.copyWith(
        issuerName: 'All',
        mDocCredentials: [mdl],
        promotionalCredentials: [promo],
        isPromotional: true,
        logoUrl: 'https://issuer.test/logo',
      );
      expect(combined.allCredentials, [promo, vc, mdl]);
      expect(combined.primaryCredential, same(promo));
      expect(combined.totalCount, 3);
      expect(combined.hasMultiple, isTrue);
      expect(combined.isPromotional, isTrue);
      expect(combined.copyWith().logoUrl, 'https://issuer.test/logo');
      expect(combined.copyWith().issuerName, 'All');
    },
  );

  test(
    'informational cards honor dismissal and expiry without changing identity',
    () {
      final original = DefaultPromotionalCredentials.all.first;
      expect(original.isActive, isTrue);
      expect(original.isExpired, isFalse);
      expect(original.issuerName, 'PrivacyIDEA Wallet');
      final dismissed = original.copyWith(isDismissed: true);
      expect(dismissed.isActive, isFalse);
      expect(dismissed, original);
      expect(dismissed.hashCode, original.hashCode);
      expect(original == Object(), isFalse);
      expect(original.copyWith(id: 'other'), isNot(original));
      final updated = original.copyWith(
        title: 'Updated',
        subtitle: 'Details',
        description: 'Description',
        icon: Icons.info,
        gradientColors: [Colors.blue],
        expiresAt: DateTime(2000),
      );
      expect(updated.isExpired, isTrue);
      expect(updated.isActive, isFalse);
      expect(updated.title, 'Updated');
      expect(updated.subtitle, 'Details');
      expect(updated.description, 'Description');
      expect(updated.icon, Icons.info);
      expect(updated.gradientColors, [Colors.blue]);
      expect(updated.toString(), contains('title: Updated'));
    },
  );
}
